library(easypackages)

libraries(c("readxl", "readr", "plyr", "dplyr", "ggplot2", "png", "tidyverse", "reshape2", "scales", "rgdal", 'rgeos', "tmaptools", 'sp', 'sf', 'maptools', 'leaflet', 'leaflet.extras', 'spdplyr', 'geojsonio', 'rmapshaper', 'jsonlite', 'httr', 'rvest', 'stringr'))

options(scipen = 999)

github_repo_dir <- "./GitHub/pcn_hi_2022_des"

source_directory <- paste0(github_repo_dir, '/data')
output_directory <- paste0(github_repo_dir, '/outputs')
areas_to_loop <- c('West Sussex', 'Adur', 'Arun', 'Chichester', 'Crawley', 'Horsham', 'Mid Sussex', 'Worthing')

# PCN organisation data ####

download.file('https://nhs-prod.global.ssl.fastly.net/binaries/content/assets/website-assets/services/ods/data-downloads-other-nhs-organisations/epcn.zip', paste0(source_directory, '/epcn.zip'), mode = 'wb')
unzip(paste0(source_directory, '/epcn.zip'), exdir = source_directory)

PCN_data <- read_excel(paste0(source_directory, "/ePCN.xlsx"),
                       sheet = 'PCNDetails') %>% 
  rename(PCN_code = 'PCN Code',
         PCN_name = 'PCN Name',
         Current_CCG_code = 'Current Clinical \r\nCommissioning \r\nGroup Code',
         Current_CCG_name = 'Clinical\r\nCommissioning\r\nGroup Name',
         Open_date = 'Open Date',
         Close_date = 'Close Date') %>% 
  mutate(Open_date = paste(substr(Open_date, 1,4), substr(Open_date, 5,6), substr(Open_date, 7,8), sep = '-')) %>% 
  mutate(Open_date = as.Date(Open_date)) %>% 
  mutate(Address_label = gsub(', NA','', paste(str_to_title(`Address Line 1`), str_to_title(`Address Line 2`),str_to_title(`Address Line 3`),str_to_title(`Address Line 4`), Postcode, sep = ', '))) %>% 
  filter(Current_CCG_name == 'NHS WEST SUSSEX CCG') %>% 
  mutate(PCN_name = gsub('\\(Aic\\)', '\\(AIC\\)', gsub('\\(Acf\\)', '\\(ACF\\)', gsub('Pcn', 'PCN', gsub('And', 'and',  gsub(' Of ', ' of ',  str_to_title(PCN_name))))))) %>% 
  select(PCN_code, PCN_name, Postcode, Address_label)
                       
Practice_to_PCN_lookup <- read_excel("GitHub/pcn_hi_2022_des/data/ePCN.xlsx", 
           sheet = "PCN Core Partner Details") %>%
  rename(Partner_name = 'Partner\r\nName',
         ODS_code = 'Partner\r\nOrganisation\r\nCode',
         Partner_CCG_name = 'Practice\r\nParent\r\nCCG Name',
         PCN_CCG_name = 'PCN Parent\r\nCCG Name') %>% 
  mutate(Partner_name = gsub('\\(Aic\\)', '\\(AIC\\)', gsub('\\(Acf\\)', '\\(ACF\\)', gsub('Pcn', 'PCN', gsub('And', 'and',  gsub(' Of ', ' of ',  str_to_title(Partner_name))))))) %>% 
  filter(Partner_CCG_name == 'NHS WEST SUSSEX CCG' | PCN_CCG_name == 'NHS WEST SUSSEX CCG')

# GP Practice and PCN populations ####
calls_patient_numbers_webpage <- read_html('https://digital.nhs.uk/data-and-information/publications/statistical/patients-registered-at-a-gp-practice') %>%
  html_nodes("a") %>%
  html_attr("href")

# we know the actual page we want has a url which starts with the following string, so reduce the scraped list above to those which include it
calls_patient_numbers_webpage <- unique(grep('/data-and-information/publications/statistical/patients-registered-at-a-gp-practice', calls_patient_numbers_webpage, value = T))

# We also know that the top result will be the latest version (even though the second result is the next upcoming version)
calls_patient_numbers_webpage <- read_html(paste0('https://digital.nhs.uk/',calls_patient_numbers_webpage[1])) %>%
  html_nodes("a") %>%
  html_attr("href")

# Now we know that the file we want contains the string 'gp-reg-pat-prac-quin-age.csv' we can use that in the read_csv call.
# I have also tidied it a little bit by renaming the Sex field and giving R some meta data about the order in which the age groups should be
latest_gp_practice_numbers <- read_csv(unique(grep('gp-reg-pat-prac-quin-age.csv', calls_patient_numbers_webpage, value = T))) %>% 
  mutate(Sex = factor(ifelse(SEX == 'FEMALE', 'Female', ifelse(SEX == 'MALE', 'Male', ifelse(SEX == 'ALL', 'Persons', NA))), levels = c('Female', 'Male'))) %>%
  mutate(Age_group = factor(paste0(gsub('_', '-', AGE_GROUP_5), ' years'), levels = c('0-4 years', '5-9 years', '10-14 years', '15-19 years', '20-24 years', '25-29 years', '30-34 years', '35-39 years', '40-44 years', '45-49 years', '50-54 years', '55-59 years', '60-64 years', '65-69 years', '70-74 years', '75-79 years', '80-84 years', '85-89 years', '90-94 years', '95+ years'))) %>% 
  filter(AGE_GROUP_5 != 'ALL') %>% 
  filter(Sex != 'Persons') %>% 
  rename(ODS_Code = ORG_CODE,
         Patients = NUMBER_OF_PATIENTS) %>% 
  select(EXTRACT_DATE, ODS_Code, Sex, Age_group, Patients) %>% 
  mutate(EXTRACT_DATE = paste0(ordinal(as.numeric(substr(EXTRACT_DATE,1,2))), ' ', substr(EXTRACT_DATE, 3,5), ' ', substr(EXTRACT_DATE, 6,10))) %>% 
  group_by(ODS_Code) %>% 
  mutate(Proportion = Patients / sum(Patients)) %>%  # We may also want to standardise the pyramid to compare bigger and smaller practices by their age structure
  ungroup()

practice_list_size_public <- latest_gp_practice_numbers %>% 
  group_by(ODS_Code, Sex) %>% 
  summarise(Patients = sum(Patients, na.rm = TRUE)) %>% 
  ungroup() %>% 
  pivot_wider(names_from = 'Sex',
              values_from = 'Patients') %>% 
  mutate(Total = Male + Female)

# Combine this population data with the PCN_data table ####


PCN_data


# PCN boundaries ####

lsoa_pcn_lookup <- read_csv(paste0(source_directory, '/lsoa_pcn_lookup_Feb_22.csv')) %>% 
  arrange(PCN_Code)

lsoa_clipped_spdf <- geojson_read('https://opendata.arcgis.com/datasets/e9d10c36ebed4ff3865c4389c2c98827_0.geojson',  what = "sp") %>%
  filter(LSOA11CD %in% lsoa_pcn_lookup$LSOA11CD) %>% 
  arrange(LSOA11CD) %>% 
  left_join(lsoa_pcn_lookup, by = c('LSOA11CD', 'LSOA11NM')) %>% 
  arrange(PCN_Code)

PCN_data <- PCN_data %>% 
  arrange(PCN_code)

PCN_boundary <- gUnaryUnion(lsoa_clipped_spdf, id = lsoa_clipped_spdf@data$PCN_Code)

df <- data.frame(ID = character())

# Get the IDs of spatial polygon
for (i in PCN_boundary@polygons ) { df <- rbind(df, data.frame(ID = i@ID, stringsAsFactors = FALSE))  }

# and set rowname = ID
row.names(PCN_data) <- df$ID

# Then use df as the second argument to the spatial dataframe conversion function:
pcn_spdf <- SpatialPolygonsDataFrame(PCN_boundary, PCN_data)  

geojson_write(geojson_json(pcn_spdf), file = paste0(output_directory, '/pcn_boundary_simple.geojson'))

# Deprivation lsoa ####
IMD_2019 <- read_csv('https://assets.publishing.service.gov.uk/government/uploads/system/uploads/attachment_data/file/845345/File_7_-_All_IoD2019_Scores__Ranks__Deciles_and_Population_Denominators_3.csv') %>% 
  select("LSOA code (2011)",  "Local Authority District name (2019)", "Index of Multiple Deprivation (IMD) Score", "Index of Multiple Deprivation (IMD) Rank (where 1 is most deprived)", "Index of Multiple Deprivation (IMD) Decile (where 1 is most deprived 10% of LSOAs)") %>% 
  rename(lsoa_code = 'LSOA code (2011)',
         LTLA = 'Local Authority District name (2019)',
         IMD_2019_score = 'Index of Multiple Deprivation (IMD) Score',
         IMD_2019_rank = "Index of Multiple Deprivation (IMD) Rank (where 1 is most deprived)", 
         IMD_2019_decile = "Index of Multiple Deprivation (IMD) Decile (where 1 is most deprived 10% of LSOAs)") %>% 
  mutate(IMD_2019_decile = factor(ifelse(IMD_2019_decile == 1, '10% most deprived',  ifelse(IMD_2019_decile == 2, 'Decile 2',  ifelse(IMD_2019_decile == 3, 'Decile 3',  ifelse(IMD_2019_decile == 4, 'Decile 4',  ifelse(IMD_2019_decile == 5, 'Decile 5',  ifelse(IMD_2019_decile == 6, 'Decile 6',  ifelse(IMD_2019_decile == 7, 'Decile 7',  ifelse(IMD_2019_decile == 8, 'Decile 8',  ifelse(IMD_2019_decile == 9, 'Decile 9',  ifelse(IMD_2019_decile == 10, '10% least deprived', NA)))))))))), levels = c('10% most deprived', 'Decile 2', 'Decile 3', 'Decile 4', 'Decile 5', 'Decile 6', 'Decile 7', 'Decile 8', 'Decile 9', '10% least deprived'))) %>% 
  filter(LTLA %in% c('Brighton and Hove', 'Adur', 'Arun', 'Chichester', 'Crawley', 'Horsham', 'Mid Sussex', 'Worthing', 'Eastbourne', 'Hastings', 'Lewes', 'Rother', 'Wealden')) %>% 
  arrange(desc(IMD_2019_score)) %>% 
  mutate(Rank_in_Sussex = rank(desc(IMD_2019_score))) %>% 
  mutate(Decile_in_Sussex = abs(ntile(IMD_2019_score, 10) - 11)) %>% 
  mutate(Decile_in_Sussex = factor(ifelse(Decile_in_Sussex == 1, '10% most deprived',  ifelse(Decile_in_Sussex == 2, 'Decile 2',  ifelse(Decile_in_Sussex == 3, 'Decile 3',  ifelse(Decile_in_Sussex == 4, 'Decile 4',  ifelse(Decile_in_Sussex == 5, 'Decile 5',  ifelse(Decile_in_Sussex == 6, 'Decile 6',  ifelse(Decile_in_Sussex == 7, 'Decile 7',  ifelse(Decile_in_Sussex == 8, 'Decile 8',  ifelse(Decile_in_Sussex == 9, 'Decile 9',  ifelse(Decile_in_Sussex == 10, '10% least deprived', NA)))))))))), levels = c('10% most deprived', 'Decile 2', 'Decile 3', 'Decile 4', 'Decile 5', 'Decile 6', 'Decile 7', 'Decile 8', 'Decile 9', '10% least deprived'))) %>%   mutate(UTLA = ifelse(LTLA %in% c('Brighton and Hove'),'Brighton and Hove', ifelse(LTLA %in% c('Adur', 'Arun', 'Chichester', 'Crawley', 'Horsham', 'Mid Sussex', 'Worthing'), 'West Sussex', ifelse(LTLA %in% c('Eastbourne', 'Hastings', 'Lewes', 'Rother', 'Wealden'), 'East Sussex', NA)))) %>% 
  group_by(UTLA) %>% 
  arrange(UTLA, desc(IMD_2019_score)) %>% 
  mutate(Rank_in_UTLA = rank(desc(IMD_2019_score))) %>% 
  mutate(Decile_in_UTLA = abs(ntile(IMD_2019_score, 10) - 11)) %>% 
  mutate(Decile_in_UTLA = factor(ifelse(Decile_in_UTLA == 1, '10% most deprived',  ifelse(Decile_in_UTLA == 2, 'Decile 2',  ifelse(Decile_in_UTLA == 3, 'Decile 3',  ifelse(Decile_in_UTLA == 4, 'Decile 4',  ifelse(Decile_in_UTLA == 5, 'Decile 5',  ifelse(Decile_in_UTLA == 6, 'Decile 6',  ifelse(Decile_in_UTLA == 7, 'Decile 7',  ifelse(Decile_in_UTLA == 8, 'Decile 8',  ifelse(Decile_in_UTLA == 9, 'Decile 9',  ifelse(Decile_in_UTLA == 10, '10% least deprived', NA)))))))))), levels = c('10% most deprived', 'Decile 2', 'Decile 3', 'Decile 4', 'Decile 5', 'Decile 6', 'Decile 7', 'Decile 8', 'Decile 9', '10% least deprived'))) %>% 
  mutate(UTLA = ifelse(LTLA %in% c('Brighton and Hove'),'Brighton and Hove', ifelse(LTLA %in% c('Adur', 'Arun', 'Chichester', 'Crawley', 'Horsham', 'Mid Sussex', 'Worthing'), 'West Sussex', ifelse(LTLA %in% c('Eastbourne', 'Hastings', 'Lewes', 'Rother', 'Wealden'), 'East Sussex', NA)))) %>% 
  rename(LSOA11CD = lsoa_code) %>% 
  arrange(LSOA11CD)

if(file.exists(paste0(output_directory, '/lsoa_deprivation_2019_sussex.geojson')) == FALSE){
  
  # Read in the lsoa geojson boundaries for our lsoas (actually this downloads all 30,000+ and then we filter)
  lsoa_spdf <- geojson_read('https://opendata.arcgis.com/datasets/8bbadffa6ddc493a94078c195a1e293b_0.geojson',  what = "sp") %>%
    filter(LSOA11CD %in% IMD_2019$LSOA11CD) %>% 
    arrange(LSOA11CD)
  
  df <- data.frame(ID = character())
  
  # Get the IDs of spatial polygon
  for (i in lsoa_spdf@polygons ) { df <- rbind(df, data.frame(ID = i@ID, stringsAsFactors = FALSE))  }
  
  # and set rowname = ID
  row.names(IMD_2019) <- df$ID
  
  # Then use df as the second argument to the spatial dataframe conversion function:
  lsoa_spdf_json <- SpatialPolygonsDataFrame(lsoa_spdf, IMD_2019)  
  
  geojson_write(geojson_json(lsoa_spdf), file = paste0(output_directory, '/lsoa_deprivation_2019_sussex.geojson'))
  
}



# gp locations

# Download the EPRACCUR file 
download.file('https://files.digital.nhs.uk/assets/ods/current/epraccur.zip', paste0(github_repo_dir,'/epraccur.zip'), mode = 'wb') 
unzip(paste0(github_repo_dir,'/epraccur.zip'), exdir = github_repo_dir) # unzip the folder into the directory

# Great but its got entirely capital letters for everything.
# We can use functions such as tolower() and toupper() but this works on the whole string and we probably want each word capitalised rather than all or nothing.
# Thankfully you can create a function (I did not come up with this myself, it was on the examples for chartr package)
capwords = function(s, strict = FALSE) {
  cap = function(s) paste(toupper(substring(s, 1, 1)),
                          {s = substring(s, 2); if(strict) tolower(s) else s},
                          sep = "", collapse = " " )
  sapply(strsplit(s, split = " "), cap, USE.NAMES = !is.null(names(s)))}

# We can tidy up the data frame
epraccur <- read_csv('/Users/richtyler/Documents/Repositories/primary-care-geographies/epraccur.csv', col_names = c("Code", "Name", "National Grouping", "Health Geography", "Address_1", "Address_2", "Address_3", "Address_4", "Address_5", "Postcode", "Open Date", "Close Date", "Status", "Organisation Sub-type", "Commissioner", "Join Provider date", "Left provider date", "Contact Tel.", "Null_1", "Null_2", "Null_3", "Amended Record Indicator", "Null_4", "Provider_purchaser", "Null_5", "Prescribing setting", "Null_6")) %>% 
  select(-c(`Open Date`, `National Grouping`, `Health Geography`, `Organisation Sub-type`, Null_1, Null_2, Null_3, Null_4, Null_5, Null_6, `Amended Record Indicator`, `Join Provider date`)) %>% 
  mutate(Name = capwords(Name, strict = TRUE),
         Address_1 = capwords(Address_1, strict = TRUE),
         Address_2 = capwords(Address_2, strict = TRUE),
         Address_3 = capwords(Address_3, strict = TRUE),
         Address_4 = capwords(Address_4, strict = TRUE),
         Address_5 = capwords(Address_5, strict = TRUE),
         Status = factor(ifelse(Status == 'A', 'Active', ifelse(Status == 'C', 'Closed', ifelse(Status == 'D', 'Dormant', ifelse(Status == 'P', 'Proposed', NA)))))) %>% 
  mutate(`Close Date` = as.character.Date(`Close Date`)) %>% 
  filter(Commissioner %in% c('09G','09H','09X')) %>% 
  filter(Status == 'Active') %>% 
  filter(`Prescribing setting` == 4)

PCN_data <- PCN_data %>% 
  left_join(epraccur[c('Code', 'Postcode')], by = c('GP code' = 'Code')) %>% 
  mutate(pcd_ns = tolower(gsub(' ', '', Postcode)))

# This is the postcode file from open geography portal for wsx 
postcodes_wsx <- unique(list.files("./GIS/Postcodes/multi")) %>% 
  map_df(~read_csv(paste0("./GIS/Postcodes/multi/",.))) %>% 
  select(pcd, oseast1m, osnrth1m, lat, long) %>% 
  mutate(pcd_ns = tolower(gsub(' ', '', pcd)))

PCN_data <- PCN_data %>% 
  left_join(postcodes_wsx, by = 'pcd_ns')

# Working with Open Geography Portal API to avoid needing to download data locally. 

# LAD_clipped <- st_read("https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/LAD_APR_2019_UK_BFC/FeatureServer/0/query?where=%20(LAD19NM%20like%20'%25ADUR%25'%20OR%20LAD19NM%20like%20'%25ARUN%25'%20OR%20LAD19NM%20like%20'%25CHICHESTER%25'%20OR%20LAD19NM%20like%20'%25CRAWLEY%25'%20OR%20LAD19NM%20like%20'%25HORSHAM%25'%20OR%20LAD19NM%20like%20'%25MID%20SUSSEX%25'%20OR%20LAD19NM%20like%20'%25WORTHING%25')%20&outFields=LAD19CD,LAD19NM,LAD19NMW,BNG_E,BNG_N,LONG,LAT&outSR=4326&f=geojson")
# LAD_fe <- st_read("https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/LAD_APR_2019_UK_BFE/FeatureServer/0/query?where=%20(LAD19NM%20like%20'%25ADUR%25'%20OR%20LAD19NM%20like%20'%25ARUN%25'%20OR%20LAD19NM%20like%20'%25CHICHESTER%25'%20OR%20LAD19NM%20like%20'%25CRAWLEY%25'%20OR%20LAD19NM%20like%20'%25HORSHAM%25'%20OR%20LAD19NM%20like%20'%25MID%20SUSSEX%25'%20OR%20LAD19NM%20like%20'%25WORTHING%25')%20&outFields=LAD19CD,LAD19NM,LAD19NMW,BNG_E,BNG_N,LONG,LAT&outSR=4326&f=geojson")

Chichester_clipped <- as(st_read("https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/LAD_APR_2019_UK_BFC/FeatureServer/0/query?where=%20(LAD19NM%20like%20'%25CHICHESTER%25')%20&outFields=LAD19CD,LAD19NM,LAD19NMW,BNG_E,BNG_N,LONG,LAT&outSR=4326&f=geojson"), 'Spatial')

# convert to SpatialPolygonsDataFrame
# Chichester_clipped <- as(Chichester_clipped, "Spatial")
# convert to SpatialPolygons
# Chichester_clipped <- as(st_geometry(Chichester_clipped), "Spatial")

LAD_no_chi_fe <- as(st_read("https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/LAD_APR_2019_UK_BFE/FeatureServer/0/query?where=%20(LAD19NM%20like%20'%25ADUR%25'%20OR%20LAD19NM%20like%20'%25ARUN%25'%20OR%20LAD19NM%20like%20'%25CRAWLEY%25'%20OR%20LAD19NM%20like%20'%25HORSHAM%25'%20OR%20LAD19NM%20like%20'%25MID%20SUSSEX%25'%20OR%20LAD19NM%20like%20'%25WORTHING%25')%20&outFields=LAD19CD,LAD19NM,LAD19NMW,BNG_E,BNG_N,LONG,LAT&outSR=4326&f=geojson"), 'Spatial')
# convert to SpatialPolygonsDataFrame
# LAD_no_chi_fe_spdf <- as(LAD_no_chi_fe, "Spatial")
# convert to SpatialPolygons
# LAD_no_chi_fe <- as(st_geometry(LAD_no_chi_fe), "Spatial")

LAD <- rbind(LAD_no_chi_fe, Chichester_clipped)
rm(Chichester_clipped, LAD_no_chi_fe)

# We need to do a bit of hacking this about to keep the integrity of the coastline around Chichester harbour but also making sure that we dont include clips of all the rivers in Wsx!

#Grab all full extent LSOAs for areas with LSOAs that have names starting with Adur, Arun, Chichester, Crawley, Horsham, Mid Sussex, Worthing and Lewes (as we know there are a couple of LSOAs outside of the boundary)
LSOA_boundary_fe <- as(st_read(paste0("https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/LSOA_DEC_2011_EW_BFE/FeatureServer/0/query?where=%20(LSOA11NM%20like%20'%25ADUR%25'%20OR%20LSOA11NM%20like%20'%25ARUN%25'%20OR%20LSOA11NM%20like%20'%25CHICHESTER%25'%20OR%20LSOA11NM%20like%20'%25CRAWLEY%25'%20OR%20LSOA11NM%20like%20'%25HORSHAM%25'%20OR%20LSOA11NM%20like%20'%25LEWES%25'%20OR%20LSOA11NM%20like%20'%25MID%20SUSSEX%25'%20OR%20LSOA11NM%20like%20'%25WORTHING%25')%20&outFields=LSOA11CD,LSOA11NM&outSR=4326&f=geojson")), 'Spatial')

# We can grab a subset of LSOAs for just Chichester
LSOA_boundary_clipped <- as(st_read(paste0("https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/LSOA_DEC_2011_EW_BFC/FeatureServer/0/query?where=%20(LSOA11NM%20like%20'%25CHICHESTER%25')%20&outFields=LSOA11CD,LSOA11NM&outSR=4326&f=json")), 'Spatial')

# Extract the LSOAs we know need to be clipped from the Chichester object
LSOA_boundary_clipped <- LSOA_boundary_clipped %>% 
filter(LSOA11CD %in% c('E01031532', 'E01031475','E01031476','E01031496','E01031542','E01031540','E01031524','E01031529','E01031513'))

# We want to select all the LSOAs that were not clipped in the above object
LSOA_boundary_fe <- LSOA_boundary_fe %>% 
  filter(!LSOA11CD %in% LSOA_boundary_clipped$LSOA11CD)

# Join the two objects. This will now contain all of Chichester LSOAs (some clipped and some full extent) as well as all LSOAs for the rest of WSx and Lewes. 
LSOA_boundary <- rbind(LSOA_boundary_fe, LSOA_boundary_clipped)

# We can remove the old objects
rm(LSOA_boundary_fe, LSOA_boundary_clipped)

# The extra LSOAs in Lewes need to be removed and we can then add in the PCN data from our PCN dataframe
LSOA_boundary <- LSOA_boundary %>% 
  filter(LSOA11CD %in% LSOA_PCN_data$`LSOA code in CI`) %>% 
  left_join(LSOA_PCN_data, by = c('LSOA11CD' = 'LSOA code in CI'))

PCN_data %>% 
  rename(Code = 'GP code') %>% 
  select(Code, CCG, lat, long, Colours) %>% 
  left_join(GP_num_dec_2019, by = 'Code') %>% 
  select(Code, Name, lat, long, Patients, `Patients aged 65+`, `Proportion aged 65+`, PCN, CCG, Colours) %>% 
  toJSON() %>% 
  write_lines(paste0(github_repo_dir, '/gp_lookup_pcn_overview.json'))


# Now we have a spatialpolygonsdataframe of LSOAs assigned to PCN, we can disolve the individual LSOAs into a single polygon for each PCN (although some PCNs have a couple of LSOAs not quite next to eachother)
WSx_PCN = gUnaryUnion(LSOA_boundary, id = LSOA_boundary@data$PCN)

Overview_pcn_map <- Overview %>% 
  mutate(Patients = format(Patients, big.mark = ',', trim = TRUE)) %>% 
  mutate(`Patients aged 65+` = format(`Patients aged 65+`, big.mark = ',', trim = TRUE)) %>% 
  mutate(`Proportion aged 65+` = paste0(round(`Proportion aged 65+` *100, 1), '%')) 

WSx_PCN <- SpatialPolygonsDataFrame(WSx_PCN, Overview_pcn_map,  match.ID = F) 

pcn_json <- geojson_json(WSx_PCN)
# geojson_write(pcn_json, file = paste0(github_repo_dir, "/pcn.geojson"))

pcn_json_simplified <- ms_simplify(pcn_json, keep = 0.2)
geojson_write(pcn_json_simplified, file = paste0(github_repo_dir,"/pcn_simple.geojson"))

# Same with LAD boundaries except we have wrapped the geojson convert command within the ms_simplify() command so that is happens at once (e.g. more efficient as one line instead of two)
lad_json_simplified <- ms_simplify(geojson_json(LAD), keep = 0.2)
geojson_write(lad_json_simplified, file = paste0(github_repo_dir, '/lad_simple.geojson'))

leaflet() %>%  
  addTiles(urlTemplate = "http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",attribution = "Crown copyright 2019.<br>Zoom in/out using your mouse wheel or the plus (+) and minus (-) buttons. Click on an area or GP icon to find out more") %>% 
  addPolygons(data = WSx_PCN, 
              stroke = TRUE, 
              fillColor = Overview$Colours, 
              color = '#000000', 
              weight = 1, 
              opacity = 1,
              fillOpacity = .7,
              group = "Show PCN boundaries") %>% 
  addPolygons(data = LAD,
              stroke = TRUE,
              opacity = 1,
              fill = 0,
              weight = 3,
              label = LAD@data$LAD19NM,
              group = "Show LA district & borough boundaries") %>%
  addCircleMarkers(lng = PCN_data$long,
                   lat = PCN_data$lat,
                   color = '#000000',
                   stroke = TRUE,
                   weight = 1,
                   opacity = 1,
                   fillColor = PCN_data$Colours, 
                   label = PCN_data$PCN,
                   fillOpacity = 1,
                   radius = 6,
                   group = "Show GP practices by PCN") %>%
  addResetMapButton() %>%
  addScaleBar(position = "bottomleft")# %>% 
# addPulseMarkers(lng = WSx_GPs$long, 
#                  lat = WSx_GPs$lat,
#                  icon = makePulseIcon(heartbeat = 1,
#                                       animate = T,  
#                                       color = WSx_GPs$Colours),
#                  popup = paste0("<strong>", WSx_GPs$Practice_label, "</strong>"),
#                  group = "Show GP practices by PCN") 


map_theme = function(){
  theme( 
    legend.position = "none", 
    plot.background = element_blank(), 
    panel.background = element_blank(),  
    panel.border = element_blank(),
    axis.text = element_blank(), 
    plot.title = element_text(colour = "#000000", face = "bold", size = 12), 
    axis.title = element_blank(),     
    panel.grid.major.x = element_blank(), 
    panel.grid.minor.x = element_blank(), 
    panel.grid.major.y = element_blank(), 
    panel.grid.minor.y = element_blank(), 
    strip.text = element_text(colour = "white"), 
    strip.background = element_rect(fill = "#327d9c"), 
    axis.ticks = element_blank() 
  ) 
} 

# We have to reproject LSOA11_bounday to match the projection coordinate reference system (CRS) for ggplot like the other two boundary files
# CRS("+init=epsg:4326") is WGS84
WSx_PCN_2 <- spTransform(WSx_PCN, CRS("+init=epsg:4326"))
LAD_2 <- spTransform(LAD, CRS("+init=epsg:4326"))

WSx_PCN_3 <- SpatialPolygonsDataFrame(WSx_PCN, data = data.frame(Overview), match.ID = F) 

View(WSx_PCN_2)
rm(coords)

#  This will be a good bounding box for any of our maps.
my_bbox <- matrix(data= c(-1.0518, 50.7080, 0.144380, 51.2047), nrow = 2, ncol = 2, dimnames = list(c("Latitude", "Longitude"), c("min", "max")))

ggplot() +
  coord_fixed(1.5) + 
  map_theme() +
  # scale_y_continuous(limits = c(my_bbox[2] - 0.000100, my_bbox[4] + 0.000100)) + 
  # scale_x_continuous(limits = c(my_bbox[1] - 0.00500, my_bbox[3] + 0.00500)) +
  geom_polygon(data = WSx_PCN_3, aes(x=long, y=lat, group = group, fill = group), color="#000000", size = .5, alpha = .7, show.legend = FALSE) +
  # scale_fill_manual(values = Overview$Colours) +
  geom_point(data = PCN_data, aes(x = long, y = lat, fill = PCN), shape = 21, colour = '#000000', size = 3, alpha = 1) +
  geom_polygon(data = LAD, aes(x=long, y=lat, group = group), color="#3D2EFF", fill = NA, size = 1, show.legend = FALSE) +
  scale_colour_manual(values = PCN_data$Colours) +
  theme(legend.position = "none",
        legend.title = element_text(size = 9, face = "bold"),
        legend.key.width = unit(0.2,"cm"),
        legend.key.height = unit(0.2,"cm")) 


# CVDPREVENT ####

# https://api.cvdprevent.nhs.uk/indicator/7/rawDataCSV?timePeriodID=2&systemLevelID=4
