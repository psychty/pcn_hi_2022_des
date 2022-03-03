library(easypackages)

libraries(c("readxl", "readr", "plyr", "dplyr", "ggplot2", "png", "tidyverse", "reshape2", "scales", "rgdal", 'rgeos', "tmaptools", 'sp', 'sf', 'maptools', 'leaflet', 'leaflet.extras', 'spdplyr', 'geojsonio', 'rmapshaper', 'jsonlite', 'httr', 'rvest', 'stringr', 'fingertipsR'))

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
  rename(PCN_Code = 'PCN Code',
         PCN_Name = 'PCN Name',
         Current_CCG_code = 'Current Clinical \r\nCommissioning \r\nGroup Code',
         Current_CCG_name = 'Clinical\r\nCommissioning\r\nGroup Name',
         Open_date = 'Open Date',
         Close_date = 'Close Date') %>% 
  mutate(Open_date = paste(substr(Open_date, 1,4), substr(Open_date, 5,6), substr(Open_date, 7,8), sep = '-')) %>% 
  mutate(Open_date = as.Date(Open_date)) %>% 
  mutate(Address_label = gsub(', NA','', paste(str_to_title(`Address Line 1`), str_to_title(`Address Line 2`),str_to_title(`Address Line 3`),str_to_title(`Address Line 4`), Postcode, sep = ', '))) %>% 
  filter(Current_CCG_name == 'NHS WEST SUSSEX CCG') %>% 
  mutate(PCN_Name = gsub('\\(Aic\\)', '\\(AIC\\)', gsub('\\(Acf\\)', '\\(ACF\\)', gsub('Pcn', 'PCN', gsub('And', 'and',  gsub(' Of ', ' of ',  str_to_title(PCN_Name))))))) %>% 
  select(PCN_Code, PCN_Name, Postcode, Address_label)
                       
Practice_to_PCN_lookup <- read_excel("GitHub/pcn_hi_2022_des/data/ePCN.xlsx", 
           sheet = "PCN Core Partner Details") %>%
  rename(Partner_name = 'Partner\r\nName',
         ODS_code = 'Partner\r\nOrganisation\r\nCode',
         Partner_CCG_name = 'Practice\r\nParent\r\nCCG Name',
         PCN_CCG_name = 'PCN Parent\r\nCCG Name') %>% 
  mutate(Partner_name = gsub('\\(Aic\\)', '\\(AIC\\)', gsub('\\(Acf\\)', '\\(ACF\\)', gsub('Pcn', 'PCN', gsub('And', 'and',  gsub(' Of ', ' of ',  str_to_title(Partner_name))))))) %>% 
  filter(Partner_CCG_name == 'NHS WEST SUSSEX CCG' | PCN_CCG_name == 'NHS WEST SUSSEX CCG')

# GP Practice and PCN populations ####

# Ordinarily we'd like to use the most recently available release of patients, and could use the following code to extract the latest.
# calls_patient_numbers_webpage <- read_html('https://digital.nhs.uk/data-and-information/publications/statistical/patients-registered-at-a-gp-practice') %>%
#   html_nodes("a") %>%
#   html_attr("href")
# 
# # we know the actual page we want has a url which starts with the following string, so reduce the scraped list above to those which include it
# calls_patient_numbers_webpage <- unique(grep('/data-and-information/publications/statistical/patients-registered-at-a-gp-practice', calls_patient_numbers_webpage, value = T))
# 
# # We also know that the top result will be the latest version (even though the second result is the next upcoming version)
# calls_patient_numbers_webpage <- read_html(paste0('https://digital.nhs.uk/',calls_patient_numbers_webpage[1])) %>%
#   html_nodes("a") %>%
#   html_attr("href")
# 
# # Now we know that the file we want contains the string 'gp-reg-pat-prac-quin-age.csv' we can use that in the read_csv call.
# # I have also tidied it a little bit by renaming the Sex field and giving R some meta data about the order in which the age groups should be
# latest_gp_practice_numbers <- read_csv(unique(grep('gp-reg-pat-prac-quin-age.csv', calls_patient_numbers_webpage, value = T))) %>% 
#   mutate(Sex = factor(ifelse(SEX == 'FEMALE', 'Female', ifelse(SEX == 'MALE', 'Male', ifelse(SEX == 'ALL', 'Persons', NA))), levels = c('Female', 'Male'))) %>%
#   mutate(Age_group = factor(paste0(gsub('_', '-', AGE_GROUP_5), ' years'), levels = c('0-4 years', '5-9 years', '10-14 years', '15-19 years', '20-24 years', '25-29 years', '30-34 years', '35-39 years', '40-44 years', '45-49 years', '50-54 years', '55-59 years', '60-64 years', '65-69 years', '70-74 years', '75-79 years', '80-84 years', '85-89 years', '90-94 years', '95+ years'))) %>% 
#   filter(AGE_GROUP_5 != 'ALL') %>% 
#   filter(Sex != 'Persons') %>% 
#   rename(ODS_Code = ORG_CODE,
#          Patients = NUMBER_OF_PATIENTS) %>% 
#   select(EXTRACT_DATE, ODS_Code, Sex, Age_group, Patients) %>% 
#   mutate(EXTRACT_DATE = paste0(ordinal(as.numeric(substr(EXTRACT_DATE,1,2))), ' ', substr(EXTRACT_DATE, 3,5), ' ', substr(EXTRACT_DATE, 6,10))) %>% 
#   group_by(ODS_Code) %>% 
#   mutate(Proportion = Patients / sum(Patients)) %>%  # We may also want to standardise the pyramid to compare bigger and smaller practices by their age structure
#   ungroup()
# 
# gp_numbers_mapping_wsx <-  read_csv(unique(grep('gp-reg-pat-prac-map.csv', calls_patient_numbers_webpage, value = T))) %>% 
#   filter(PCN_CODE %in% PCN_data$PCN_code)

# HOWEVER, not every release has the LSOA level numbers we need to identify which decile people are in. As such, we need to specify the January 2022 release.
calls_patient_numbers_webpage <- read_html('https://digital.nhs.uk/data-and-information/publications/statistical/patients-registered-at-a-gp-practice/january-2022') %>%
  html_nodes("a") %>%
  html_attr("href")

gp_numbers_mapping_wsx <-  read_csv(unique(grep('gp-reg-pat-prac-map.csv', calls_patient_numbers_webpage, value = T))) %>%
  filter(PCN_CODE %in% PCN_data$PCN_Code) %>% 
  rename(ODS_Code = PRACTICE_CODE,
         PCN_Code = PCN_CODE,
         ODS_Name = PRACTICE_NAME,
         Practice_postcode = PRACTICE_POSTCODE) %>%
  mutate(ODS_Name = gsub('Woodlands&Clerklands', 'Woodlands & Clerklands', gsub('\\(Aic\\)', '\\(AIC\\)', gsub('\\(Acf\\)', '\\(ACF\\)', gsub('Pcn', 'PCN', gsub('And', 'and',  gsub(' Of ', ' of ',  str_to_title(ODS_Name)))))))) %>%  
  select(ODS_Code, ODS_Name, Practice_postcode, PCN_Code) %>% 
  left_join(PCN_data[c('PCN_Code', 'PCN_Name')], by = 'PCN_Code')

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

wsx_ccg_population <- latest_gp_practice_numbers %>% 
  filter(ODS_Code == '70F') %>% 
  mutate(ODS_Name = 'NHS West Sussex CCG') %>% 
  mutate(Area_name = 'NHS West Sussex CCG') %>% 
  select(Area_name, Sex, Age_group, Patients, Proportion)

sum(wsx_ccg_population$Patients)

latest_gp_practice_numbers <- latest_gp_practice_numbers %>% 
  filter(ODS_Code %in% gp_numbers_mapping_wsx$ODS_Code) %>% # 70F is the ods code for NHS West Sussex CCG
  left_join(gp_numbers_mapping_wsx, by = 'ODS_Code') 

sum(latest_gp_practice_numbers$Patients)

pyramid_dataset <- latest_gp_practice_numbers %>% 
  group_by(PCN_Name, Sex, Age_group) %>% 
  summarise(Patients = sum(Patients, na.rm = TRUE)) %>% 
  rename(Area_name = PCN_Name) %>% 
  group_by(Area_name) %>%
  mutate(Proportion = Patients / sum(Patients)) %>%  # We may also want to standardise the pyramid to compare bigger and smaller practices by their age structure
  ungroup() 

sum(pyramid_dataset$Patients)

pyramid_dataset %>% 
  bind_rows(wsx_ccg_population) %>% 
  toJSON() %>%
  write_lines(paste0(output_directory, '/PCN_pyramid_data.json'))

# Combine population data with the PCN_data table ####
library(xfun)

n_practice_in_pcn <- latest_gp_practice_numbers %>% 
  select(ODS_Code, PCN_Code) %>% 
  unique() %>% 
  group_by(PCN_Code) %>% 
  summarise(Practices = n()) %>% 
  mutate(Practices = numbers_to_words(Practices))

practice_total_list_size_public <- latest_gp_practice_numbers %>% 
  group_by(PCN_Code, Sex) %>% 
  summarise(Patients = sum(Patients, na.rm = TRUE)) %>% 
  ungroup() %>% 
  pivot_wider(names_from = 'Sex',
              values_from = 'Patients') %>% 
  mutate(Total = Male + Female)

latest_age_pcn_numbers <- read_csv(unique(grep('gp-reg-pat-prac-sing-age-regions.csv', calls_patient_numbers_webpage, value = T))) %>%
  filter(ORG_CODE %in% PCN_data$PCN_Code) %>% 
  filter(AGE != 'ALL') %>% 
  rename(PCN_Code = ORG_CODE,
         Patients = NUMBER_OF_PATIENTS,
         Sex = SEX,
         Age = AGE) %>%
  mutate(Sex = factor(ifelse(Sex == 'FEMALE', 'Female', ifelse(Sex == 'MALE', 'Male', NA)), levels = c('Female', 'Male'))) %>%
  mutate(Age = as.numeric(gsub('95\\+', '95', Age))) %>% 
  mutate(Age_group = factor(ifelse(Age < 16, '0-15 years', ifelse(Age < 65, '16-64 years', '65+ years')), levels = c('0-15 years', '16-64 years', '65+ years'))) %>% 
  select(PCN_Code, Sex, Age_group, Patients) %>%
  group_by(PCN_Code, Age_group) %>%
  summarise(Patients = sum(Patients, na.rm = TRUE)) %>% 
  pivot_wider(names_from = 'Age_group',
              values_from = 'Patients')

PCN_data %>% 
  left_join(practice_total_list_size_public, by = 'PCN_Code') %>% 
  left_join(latest_age_pcn_numbers, by = 'PCN_Code') %>% 
  left_join(n_practice_in_pcn, by = 'PCN_Code') %>%
  toJSON() %>%
  write_lines(paste0(output_directory, '/PCN_data.json'))

# PCN boundaries ####

lsoa_pcn_lookup <- read_csv(paste0(source_directory, '/lsoa_pcn_lookup_Feb_22.csv')) %>% 
  arrange(PCN_Code)

lsoa_clipped_spdf <- geojson_read('https://opendata.arcgis.com/datasets/e9d10c36ebed4ff3865c4389c2c98827_0.geojson',  what = "sp") %>%
  filter(LSOA11CD %in% lsoa_pcn_lookup$LSOA11CD) %>% 
  arrange(LSOA11CD) %>% 
  left_join(lsoa_pcn_lookup, by = c('LSOA11CD', 'LSOA11NM')) %>% 
  arrange(PCN_Code)

PCN_data <- PCN_data %>% 
  arrange(PCN_Code)

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
IMD_2019_national <- read_csv('https://assets.publishing.service.gov.uk/government/uploads/system/uploads/attachment_data/file/845345/File_7_-_All_IoD2019_Scores__Ranks__Deciles_and_Population_Denominators_3.csv') %>% 
  select("LSOA code (2011)",  "Local Authority District name (2019)", "Index of Multiple Deprivation (IMD) Score", "Index of Multiple Deprivation (IMD) Rank (where 1 is most deprived)", "Index of Multiple Deprivation (IMD) Decile (where 1 is most deprived 10% of LSOAs)") %>% 
  rename(lsoa_code = 'LSOA code (2011)',
         LTLA = 'Local Authority District name (2019)',
         IMD_2019_score = 'Index of Multiple Deprivation (IMD) Score',
         IMD_2019_rank = "Index of Multiple Deprivation (IMD) Rank (where 1 is most deprived)", 
         IMD_2019_decile = "Index of Multiple Deprivation (IMD) Decile (where 1 is most deprived 10% of LSOAs)") %>% 
  mutate(IMD_2019_decile = factor(ifelse(IMD_2019_decile == 1, '10% most deprived',  ifelse(IMD_2019_decile == 2, 'Decile 2',  ifelse(IMD_2019_decile == 3, 'Decile 3',  ifelse(IMD_2019_decile == 4, 'Decile 4',  ifelse(IMD_2019_decile == 5, 'Decile 5',  ifelse(IMD_2019_decile == 6, 'Decile 6',  ifelse(IMD_2019_decile == 7, 'Decile 7',  ifelse(IMD_2019_decile == 8, 'Decile 8',  ifelse(IMD_2019_decile == 9, 'Decile 9',  ifelse(IMD_2019_decile == 10, '10% least deprived', NA)))))))))), levels = c('10% most deprived', 'Decile 2', 'Decile 3', 'Decile 4', 'Decile 5', 'Decile 6', 'Decile 7', 'Decile 8', 'Decile 9', '10% least deprived'))) %>% 
  rename(LSOA11CD = lsoa_code)
 
IMD_2019 <- IMD_2019_national %>% 
  filter(LTLA %in% c('Brighton and Hove', 'Adur', 'Arun', 'Chichester', 'Crawley', 'Horsham', 'Mid Sussex', 'Worthing', 'Eastbourne', 'Hastings', 'Lewes', 'Rother', 'Wealden')) %>% 
  arrange(desc(IMD_2019_score)) %>% 
  mutate(Rank_in_Sussex = rank(desc(IMD_2019_score))) %>% 
  mutate(Decile_in_Sussex = abs(ntile(IMD_2019_score, 10) - 11)) %>% 
  mutate(Decile_in_Sussex = factor(ifelse(Decile_in_Sussex == 1, '10% most deprived',  ifelse(Decile_in_Sussex == 2, 'Decile 2',  ifelse(Decile_in_Sussex == 3, 'Decile 3',  ifelse(Decile_in_Sussex == 4, 'Decile 4',  ifelse(Decile_in_Sussex == 5, 'Decile 5',  ifelse(Decile_in_Sussex == 6, 'Decile 6',  ifelse(Decile_in_Sussex == 7, 'Decile 7',  ifelse(Decile_in_Sussex == 8, 'Decile 8',  ifelse(Decile_in_Sussex == 9, 'Decile 9',  ifelse(Decile_in_Sussex == 10, '10% least deprived', NA)))))))))), levels = c('10% most deprived', 'Decile 2', 'Decile 3', 'Decile 4', 'Decile 5', 'Decile 6', 'Decile 7', 'Decile 8', 'Decile 9', '10% least deprived'))) %>% 
  mutate(UTLA = ifelse(LTLA %in% c('Brighton and Hove'),'Brighton and Hove', ifelse(LTLA %in% c('Adur', 'Arun', 'Chichester', 'Crawley', 'Horsham', 'Mid Sussex', 'Worthing'), 'West Sussex', ifelse(LTLA %in% c('Eastbourne', 'Hastings', 'Lewes', 'Rother', 'Wealden'), 'East Sussex', NA)))) %>% 
  group_by(UTLA) %>% 
  arrange(UTLA, desc(IMD_2019_score)) %>% 
  mutate(Rank_in_UTLA = rank(desc(IMD_2019_score))) %>% 
  mutate(Decile_in_UTLA = abs(ntile(IMD_2019_score, 10) - 11)) %>% 
  mutate(Decile_in_UTLA = factor(ifelse(Decile_in_UTLA == 1, '10% most deprived',  ifelse(Decile_in_UTLA == 2, 'Decile 2',  ifelse(Decile_in_UTLA == 3, 'Decile 3',  ifelse(Decile_in_UTLA == 4, 'Decile 4',  ifelse(Decile_in_UTLA == 5, 'Decile 5',  ifelse(Decile_in_UTLA == 6, 'Decile 6',  ifelse(Decile_in_UTLA == 7, 'Decile 7',  ifelse(Decile_in_UTLA == 8, 'Decile 8',  ifelse(Decile_in_UTLA == 9, 'Decile 9',  ifelse(Decile_in_UTLA == 10, '10% least deprived', NA)))))))))), levels = c('10% most deprived', 'Decile 2', 'Decile 3', 'Decile 4', 'Decile 5', 'Decile 6', 'Decile 7', 'Decile 8', 'Decile 9', '10% least deprived'))) %>% 
  mutate(UTLA = ifelse(LTLA %in% c('Brighton and Hove'),'Brighton and Hove', ifelse(LTLA %in% c('Adur', 'Arun', 'Chichester', 'Crawley', 'Horsham', 'Mid Sussex', 'Worthing'), 'West Sussex', ifelse(LTLA %in% c('Eastbourne', 'Hastings', 'Lewes', 'Rother', 'Wealden'), 'East Sussex', NA)))) %>% 
  arrange(LSOA11CD) %>% 
  filter(LSOA11CD %in% lsoa_pcn_lookup$LSOA11CD) %>% 
  select(LSOA11CD, LTLA, IMD_2019_decile, IMD_2019_rank) %>% 
  left_join(lsoa_pcn_lookup[c('LSOA11CD', 'LSOA11NM', 'PCN_Name')], by = 'LSOA11CD')
  
if(file.exists(paste0(output_directory, '/lsoa_deprivation_2019_west_sussex.geojson')) == FALSE){
  
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
  
  geojson_write(geojson_json(lsoa_spdf_json), file = paste0(output_directory, '/lsoa_deprivation_2019_west_sussex.geojson'))
  
}

# GP locations
library(PostcodesioR)

lookup_result <- data.frame(postcode = character(), longitude = double(), latitude = double())
  
  for(i in 1:nrow(gp_numbers_mapping_wsx)){
    lookup_result_x <- postcode_lookup(gp_numbers_mapping_wsx$Practice_postcode[i]) %>% 
      select(postcode, longitude, latitude)
    
    lookup_result <- lookup_result_x %>% 
      bind_rows(lookup_result)
    
  }
  
gp_locations <- gp_numbers_mapping_wsx %>%
  rename(postcode = Practice_postcode) %>% 
  left_join(lookup_result, by = 'postcode')  

# Number of patients in each quintile ####
download.file(unique(grep('gp-reg-pat-prac-lsoa-male-female', calls_patient_numbers_webpage, value = T)), paste0(source_directory, '/gp_reg_lsoa.zip'), mode = 'wb')
unzip(paste0(source_directory, '/gp_reg_lsoa.zip'), exdir = source_directory)

file.remove(paste0(source_directory, '/gp-reg-pat-prac-lsoa-female.csv'))
file.remove(paste0(source_directory, '/gp-reg-pat-prac-lsoa-male.csv'))

gp_lsoa_df <- read_csv(paste0(source_directory, '/gp-reg-pat-prac-lsoa-all.csv')) %>% 
  rename(ODS_Code = PRACTICE_CODE,
         LSOA11CD = LSOA_CODE) %>% 
  filter(ODS_Code %in% gp_numbers_mapping_wsx$ODS_Code) %>% 
  left_join(IMD_2019_national, by = 'LSOA11CD')

gp_dep_df <- gp_lsoa_df %>%
  mutate(Quintile = factor(ifelse(is.na(IMD_2019_decile), 'Unknown', ifelse(IMD_2019_decile %in% c('10% most deprived', 'Decile 2'), '20% most deprived', ifelse(IMD_2019_decile %in% c('Decile 3', 'Decile 4'), 'Quintile 2', ifelse(IMD_2019_decile %in% c('Decile 5', 'Decile 6'), 'Quintile 3', ifelse(IMD_2019_decile %in% c('Decile 7', 'Decile 8'), 'Quintile 4', ifelse(IMD_2019_decile %in% c('Decile 9', '10% least deprived'), '20% least deprived', NA)))))), levels = c('20% most deprived', 'Quintile 2', 'Quintile 3', 'Quintile 4', '20% least deprived', 'Unknown'))) %>% 
  group_by(ODS_Code, Quintile) %>% 
  summarise(Patients = sum(NUMBER_OF_PATIENTS, na.rm = TRUE)) %>% 
  group_by(ODS_Code) %>% 
  mutate(Proportion = Patients / sum(Patients)) %>% 
  left_join(gp_locations, by = 'ODS_Code') %>% 
  mutate(Type = 'GP') %>% 
  rename(Area_Code = ODS_Code,
         Area_Name = ODS_Name)

pcn_dep_df <- gp_dep_df %>% 
  group_by(PCN_Code, PCN_Name, Quintile) %>% 
  summarise(Patients = sum(Patients, na.rm = TRUE)) %>% 
  group_by(PCN_Code, PCN_Name) %>% 
  mutate(Proportion = Patients / sum(Patients)) %>% 
  mutate(Type = 'PCN') %>% 
  rename(Area_Code = PCN_Code,
         Area_Name = PCN_Name)

dep_df <- gp_dep_df %>% 
  select(-c(PCN_Code, PCN_Name)) %>% 
  bind_rows(pcn_dep_df) %>% 
  select(Area_Code, Area_Name, Type, Quintile, Patients) %>% 
  arrange(Quintile) %>% 
  pivot_wider(names_from = 'Quintile',
              values_from = 'Patients') %>% 
  mutate(`20% most deprived` = replace_na(`20% most deprived`, 0),
         `Quintile 2` = replace_na(`Quintile 2`, 0),
         `Quintile 3` = replace_na(`Quintile 3`, 0),
         `Quintile 4` = replace_na(`Quintile 4`, 0),
         `20% least deprived` = replace_na(`20% least deprived`, 0),
         Unknown = replace_na(Unknown, 0)) %>% 
  mutate(Total = `20% most deprived` + `Quintile 2` + `Quintile 3` + `Quintile 4` + `20% least deprived` + Unknown) %>% 
  left_join(gp_locations, by = c('Area_Code' = 'ODS_Code')) %>% 
  mutate(PCN_Name = ifelse(is.na(PCN_Name), Area_Name, PCN_Name)) %>% 
  select(Area_Code, Area_Name, Type, `20% most deprived`, `Quintile 2`, `Quintile 3`, `Quintile 4`, `20% least deprived`, Unknown, Total, longitude, latitude, PCN_Code, PCN_Name) 

dep_df %>% 
  rename(lat = latitude,
         long = longitude) %>% 
  toJSON() %>% 
  write_lines(paste0(output_directory, '/PCN_deprivation_data.json'))

# MSOA inequalities ####



# Local Health data from fingertips

local_health_metadata <- read_csv('https://fingertips.phe.org.uk/api/indicator_metadata/csv/by_profile_id?profile_id=143') %>%
  rename(ID = 'Indicator ID',
         Source = 'Data source') %>% 
  select(ID, Definition, Rationale, Methodology, Source)

msoa_local_health_data <- read_csv('https://fingertips.phe.org.uk/api/all_data/csv/by_profile_id?child_area_type_id=3&parent_area_type_id=402&profile_id=143&parent_area_code=E10000032') %>% 
  filter(is.na(Category)) %>% 
  select(!c('Parent Code', 'Parent Name', 'Category Type', 'Category', 'Lower CI 99.8 limit', 'Upper CI 99.8 limit', 'Recent Trend', 'New data', 'Compared to goal')) %>% 
  rename(ID = 'Indicator ID',
         Indicator_Name = 'Indicator Name',
         Area_Code = 'Area Code',
         Area_Name = 'Area Name',
         Type = 'Area Type',
         Period = 'Time period',
         Lower_CI = 'Lower CI 95.0 limit',
         Upper_CI = 'Upper CI 95.0 limit',
         Numerator = 'Count',
         Compared_to_eng = 'Compared to England value or percentiles',
         Compared_to_wsx = 'Compared to Counties & UAs (from Apr 2021) value or percentiles',
         Note = 'Value note') %>% 
  mutate(Indicator = trimws(paste(ifelse(Indicator_Name == 'Life expectancy at birth, (upper age band 90+)', Sex, ''), Indicator_Name, Age, Period, sep = ' '), which = 'left')) %>% 
  select(ID, Indicator, Area_Code, Area_Name, Value, Lower_CI, Upper_CI, Numerator, Denominator, Note, Compared_to_wsx, Compared_to_eng)

England_local_health_data <- msoa_local_health_data %>% 
  filter(Area_Name == 'England')

WSx_local_health_Data <- msoa_local_health_data %>% 
  filter(Area_Name == 'West Sussex')

msoa_local_health_data <- msoa_local_health_data %>% 
  filter(Area_Name != 'England') %>% 
  filter(Area_Name != 'West Sussex') %>% 
  left_join(local_health_metadata, by = 'ID')

indicators_from_local_health <- msoa_local_health_data %>% 
  select(ID, Indicator) %>% 
  unique()

inequalities_data <- msoa_local_health_data %>% 
  filter(ID %in% c('93283', '93097', '93098', '93280', '93227', '93229', '93231', '93232', '93233', '93250', '93252', '93253', '93254', '93255', '93256', '93257', '93259', '93260'))

msoa_names <- read_csv('https://houseofcommonslibrary.github.io/msoanames/MSOA-Names-Latest.csv') %>%
  select(msoa11cd, msoa11hclnm) %>%
  rename(Area_Code = msoa11cd)

inequalities_data_summary <- inequalities_data %>% 
  select(Indicator, Area_Code, Value) %>% 
  pivot_wider(names_from = 'Indicator',
              values_from = 'Value') %>% 
  rename(Unemployment = 'Unemployment (% of the working age population claiming out of work benefit) 16-64 yrs 2019/20',
         Long_term_unemployment = 'Long-Term Unemployment- rate per 1,000 working age population 16-64 yrs 2019/20',
         HH_in_fuel_poverty = 'Estimated percentage of households that experience fuel poverty, 2018 Not applicable 2018',
         Male_LE_at_birth = 'Male Life expectancy at birth, (upper age band 90+) All ages 2015 - 19',
         Female_LE_at_birth = 'Female Life expectancy at birth, (upper age band 90+) All ages 2015 - 19',
         Hosp_all_cause = 'Emergency hospital admissions for all causes, all ages, standardised admission ratio All ages 2015/16 - 19/20') %>% 
  arrange(Area_Code) %>% 
  left_join(msoa_names, by = 'Area_Code')

summary(inequalities_data_summary$Hosp_all_cause)

# MSOA geographies ####
# lsoa_to_msoa <- read_csv('https://opendata.arcgis.com/datasets/a46c859088a94898a7c462eeffa0f31a_0.csv') %>% 
#   select(LSOA11CD, MSOA11CD, MSOA11NM) %>% 
#   unique() %>% 
#   left_join(lsoa_pcn_lookup, by = 'LSOA11CD') %>% 
#   filter(!is.na(PCN_Name))
# 
# lsoa_to_msoa %>% 
#   write.csv(., paste0(source_directory, '/lsoa_to_msoa.csv'), row.names = FALSE)

lsoa_to_msoa <- read_csv(paste0(source_directory, '/lsoa_to_msoa.csv'))

msoa_boundaries_json <- geojson_read(paste0(source_directory, '/failsafe_msoa_boundary.geojson'),  what = "sp") %>% 
  filter(MSOA11CD %in% inequalities_data_summary$Area_Code) %>%
  arrange(MSOA11CD)

df <- data.frame(ID = character())

# Get the IDs of spatial polygon
for (i in msoa_boundaries_json@polygons ) { df <- rbind(df, data.frame(ID = i@ID, stringsAsFactors = FALSE))  }

# and set rowname = ID
row.names(inequalities_data_summary) <- df$ID

# Then use df as the second argument to the spatial dataframe conversion function:
msoa_boundaries_json <- SpatialPolygonsDataFrame(msoa_boundaries_json, inequalities_data_summary)  

geojson_write(geojson_json(msoa_boundaries_json), file = paste0(output_directory, '/msoa_inequalities.geojson'))

viridis::turbo(9)
# Cancer ####
# Screening at GP level ####

# CVDPREVENT ####

# https://api.cvdprevent.nhs.uk/indicator/7/rawDataCSV?timePeriodID=2&systemLevelID=4
