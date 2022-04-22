library(easypackages)

libraries(c("readxl", "readr", "plyr", "dplyr", "ggplot2", "png", "tidyverse", "reshape2", "scales", "rgdal", 'rgeos', "tmaptools", 'sp', 'sf', 'maptools', 'leaflet', 'leaflet.extras', 'spdplyr', 'geojsonio', 'rmapshaper', 'jsonlite', 'httr', 'rvest', 'stringr', 'fingertipsR'))

options(scipen = 999)

github_repo_dir <- "./GitHub/pcn_hi_2022_des"

source_directory <- paste0(github_repo_dir, '/data')
output_directory <- paste0(github_repo_dir, '/outputs')
areas_to_loop <- c('West Sussex', 'Adur', 'Arun', 'Chichester', 'Crawley', 'Horsham', 'Mid Sussex', 'Worthing')

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


# Local Health data from fingertips

# fingertips areatypes = 7 gp, 102 utla, 101 ltla, 204 PCN

cancer_services_metadata <- read_csv('https://fingertips.phe.org.uk/api/indicator_metadata/csv/by_profile_id?profile_id=92') %>%
  rename(ID = 'Indicator ID',
         Source = 'Data source') %>% 
  select(ID, Indicator, Definition, Rationale, Methodology, Source)

cancer_services_data <- read_csv('https://fingertips.phe.org.uk/api/all_data/csv/by_profile_id?child_area_type_id=7&parent_area_type_id=204&profile_id=92&parent_area_code=E10000032') %>% 
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
   select(ID, Indicator, Area_Code, Area_Name, Value, Lower_CI, Upper_CI, Numerator, Denominator, Note, Compared_to_wsx, Compared_to_eng, Sex)

  
  276 QOF_cancer_prevalence_all_age
  91337 Crude_incidence_rate_per_100000
  91355 Emergency_admissions_with_cancer
  91356 Emergency_presentation_route
  91357 Non_emergency_presentation_route
  91339 Breast_screen_three_yr_coverage_50_70
  91340 Breast_screen_within_six_months_of_invite_50_70
  91341 Cervical_screen_coverage_females
  93725 Cervical_screen_coverage_three_and_half_yr_25_49
  93726 Cervical_screen_coverage_five_and_half_yr_50_64
  92600 Bowel_screen_coverage_thirty_months_60_74
  92601 Bowel_screen_coverage_within_six_months_of_invite_60_74
  91845 TWW_conversion_rate
  91344 TWW_standardised_rate
  91882 TWW_suspected_referrals_crude_rate
  91348 TWW_suspected_breast_referrals_crude_rate
  91349 TWW_suspected_lower_gi_referrals_crude_rate
  91350 TWW_suspected_lung_referrals_crude_rate
  91351 TWW_suspected_skin_referrals_crude_rate
  
  # Staging #####
  
  # Cancers are catergorised into 3 groups:
  #   
  #   Stageable: A cancer is considered stageable if a staging system exists for its morphology and site (topography) combination. noma of the ileum are not considered stageable.The morphology and site combinations are based on the suggested sites and morphologies listed in the UICC (Union for International Cancer Control) TNM classification and published in the UKIACR (UK and Ireland Association of Cancer Registries) Performance Indicators.Amendments can be implemented to the classification by agreement through the UKIACR. Certain exceptions to the PI definitions are applied: cervical cancers staged with TNM only are excluded; colorectal cancers staged with Dukes only are excluded.
  # Unstageable: A cancer is considered unstageable if a staging system does not exist for its morphology and site (topography) combination.
  # Missing stage: A cancer is considered to have a missing stage if it has a valid morphology and site combination within a staging system, but no or partial stage information. Therefore, it is missing due to a lack of submitted data.
  # Stage breakdowns primarily use TNM (Tumour Node Metastases) staging, except: ovary and uterus cancers which use FIGO staging supplemented by TNM stage; cervix cancer which use FIGO staging only; lymphomas which use Ann Arbor staging; myelomas which use ISS staging; Binet for Chronic Lymphocytic Leukaemia (CLL); Chang for medulloblastoma;INRG staging system for neuroblastoma and NWTS system for Wilms tumour. For these cancer sites, TNM stage is used where the site-specific stage was unknown. The final recorded stage of a cancer is derived by the registration service using all information available typically up to 4 months after diagnosis, unless there is clear evidence of progression within that time, or specific information is received which warrants a longer time period to be used. The site-specific components are collated into stages 1, 2, 3, 4, Staged - other early and staged - other advanced.
  # 
  # Stage 1 = TNM stage 1, FIGO stage 1, Ann Arbor stage 1
  # Stage 2 = TNM stage 2, FIGO stage 2, Ann Arbor stage 2
  # Stage 3 = TNM stage 3, FIGO stage 3, Ann Arbor stage 3
  # Stage 4 = TNM stage 4, FIGO stage 4, Ann Arbor stage 4
  # Staged - other early = Binet A-B; ISS 1-2; Chang M0-M2; INRGSS L1-L2; NWTS 1-2
  # Staged - other advanced = Binet C; ISS 3-4; Chang M3-M4; INRGSS M&MS; NWTS 3-5
  # Both TNM staging system and site/group-specific staging systems have been mapped to early (referred to as stages 1 & 2) or advanced stage (referred to as stages 3 & 4) as follows:
  #   
  #   Stages 1 & 2 = Stage 1, Stage 2, Staged - other early
  # Stages 3 & 4 = Stage 3, Stage 4, Staged - other advanced
  # Definitions
  # Complete case approach: A methodology to calculate an outcome such as the percentage of early stage cancers. Only cancers with a known staging value are included in the denominator. Previously, cancers with unknown staging information were assumed to be advanced stage. The change of definition is supported by previous research which supports a complete case analysis being appropriate when comparing diagnosis of cancer at stages 1 and 2 between CCGs.
  # Confidence interval: is a range of values that is used to quantify the imprecision in the estimate of an indicator. A wider confidence interval shows that the indicator value presented is likely to be a less precise estimate of the true underlying value.
  # Deprivation: This is measured as the whole of the Indices of Multiple Deprivation. See Ministry of Housing, Communities & Local Government, Indices of Deprivation 2015 and Indices of Deprivation 2019 for more information.
  # Registerable: A diagnosis which is recorded by the cancer registration officers. More details can be found in the National Cancer Registration Data Profile
  
  
cancer_staging <- read_csv('https://nhsd-ndrs.shinyapps.io/staging_data_in_england/_w_827b3ef5/session/7b6367fe08bf7e73e4af6204494642d2/download/downloaddata2?w=827b3ef5.csv')
    
cancer_staging_by_site <- read_csv('https://nhsd-ndrs.shinyapps.io/staging_data_in_england/_w_827b3ef5/session/7b6367fe08bf7e73e4af6204494642d2/download/downloaddata3?w=827b3ef5.csv')

cancer_staging_by_quintile_dep <- read_csv('https://nhsd-ndrs.shinyapps.io/staging_data_in_england/_w_827b3ef5/session/7b6367fe08bf7e73e4af6204494642d2/download/downloaddata4?w=827b3ef5.csv')                                                                                 

cancer_staging_by_geography <- read_csv('https://nhsd-ndrs.shinyapps.io/staging_data_in_england/_w_827b3ef5/session/7b6367fe08bf7e73e4af6204494642d2/download/downloadsummary?w=827b3ef5.csv')
