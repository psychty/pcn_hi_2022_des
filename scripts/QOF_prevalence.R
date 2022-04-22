library(easypackages)

libraries(c("readxl", "readr", "plyr", "dplyr", "ggplot2", "png", "tidyverse", "reshape2", "scales", "rgdal", 'rgeos', "tmaptools", 'sp', 'sf', 'maptools', 'leaflet', 'leaflet.extras', 'spdplyr', 'geojsonio', 'rmapshaper', 'jsonlite', 'httr', 'rvest', 'stringr', 'fingertipsR', 'epitools'))

options(scipen = 999)

github_repo_dir <- "~/GitHub/pcn_hi_2022_des"

source_directory <- paste0(github_repo_dir, '/data')
output_directory <- paste0(github_repo_dir, '/outputs')
areas_to_loop <- c('West Sussex', 'Adur', 'Arun', 'Chichester', 'Crawley', 'Horsham', 'Mid Sussex', 'Worthing')

gp_lookup <- fromJSON(paste0(output_directory,'/PCN_deprivation_data.json')) %>% 
  filter(Type == 'GP') %>% 
  select(Area_Code, Area_Name, PCN_Code, PCN_Name)

ind_group = read_csv(paste0(source_directory, '/MAPPING_INDICATORS_2021_v2.csv')) %>% 
  select(GROUP_CODE, GROUP_DESCRIPTION) %>%
  unique() %>% 
  rename(Condition_code = GROUP_CODE,
         Condition = GROUP_DESCRIPTION) %>% 
  mutate(Condition_group = ifelse(Condition_code %in% c('AF', 'CHD', 'HF', 'HYP', 'PAD', 'STIA'), 'Cardiovascular', ifelse(Condition_code %in% c('AST', 'COPD'), 'Respiratory', ifelse(Condition_code %in% c('OB'), 'Obesity', ifelse(Condition_code %in% c('CAN', 'CKD', 'DM', 'PC'), 'High dependency/long term', ifelse(Condition_code %in% c('DEM', 'DEP','EP','LD','MH'), 'Mental health/neurology', ifelse(Condition_code %in% c('OST', 'RA'), 'Musculoskeletal', ifelse(Condition_code %in% c('NDH'), 'Non-diabetic hyperglycaemia', NA))))))))

# QOF2021 aggregated
# download.file('https://files.digital.nhs.uk/AC/3C964F/QOF2021_v2.zip', paste0(source_directory, 'QOF_2021.zip'), mode = 'wb')
# unzip(paste0(source_directory, 'QOF_2021.zip'), exdir = source_directory)

qof_prev_raw <- read_csv(paste0(source_directory, '/PREVALENCE_2021_v2.csv')) %>% 
  rename(Area_Code = PRACTICE_CODE,
         Condition_code = GROUP_CODE,
         Numerator = REGISTER,
         Denominator = PRACTICE_LIST_SIZE,
         Age_group = PATIENT_LIST_TYPE) %>% 
  mutate(Age_group = ifelse(Age_group == 'TOTAL', 'All ages', ifelse(Age_group == '06OV', '6+ years', ifelse(Age_group == '16OV', '16+ years', ifelse(Age_group == '17OV', '17+ years', ifelse(Age_group == '18OV', '18+ years', ifelse(Age_group == '50OV', '50+ years', NA))))))) %>% 
  left_join(ind_group, by = 'Condition_code') 

qof_national_prev <- qof_prev_raw %>% 
  group_by(Condition_code, Condition, Condition_group, Age_group) %>% 
  summarise(Numerator = sum(Numerator, na.rm = TRUE),
            Denominator = sum(Denominator, na.rm = TRUE)) %>% 
  mutate(Area_Code = NA,
         Area_Name = 'England',
         Type = 'National')

qof_prev_wsx_gps <- qof_prev_raw %>% 
  filter(Area_Code %in% gp_lookup$Area_Code) %>% 
  left_join(gp_lookup, by = 'Area_Code') %>% 
  mutate(Type = 'GP') %>% 
  select(Area_Code, Area_Name, Condition_code, Condition, Condition_group, Type, Age_group, Numerator, Denominator)

qof_prev_wsx_pcns <- qof_prev_raw %>% 
  filter(Area_Code %in% gp_lookup$Area_Code) %>% 
  left_join(gp_lookup, by = 'Area_Code') %>% 
  group_by(PCN_Code, PCN_Name, Age_group, Condition_code, Condition, Condition_group) %>% 
  summarise(Numerator = sum(Numerator, na.rm = TRUE),
            Denominator = sum(Denominator, na.rm = TRUE)) %>% 
  mutate(Type = 'PCN') %>% 
  rename(Area_Code = PCN_Code,
         Area_Name = PCN_Name)

qof_prev_wsx <- qof_prev_wsx_gps %>% 
  group_by(Age_group, Condition_code, Condition, Condition_group) %>% 
  summarise(Numerator = sum(Numerator, na.rm = TRUE),
            Denominator = sum(Denominator, na.rm = TRUE)) %>% 
  mutate(Type = 'West Sussex') %>% 
  mutate(Area_Name = 'West Sussex')

# We should be able to get PCN level prevalence from this.

qof_prev <- qof_prev_wsx_gps %>% 
  bind_rows(qof_prev_wsx_pcns) %>% 
  bind_rows(qof_prev_wsx) %>% 
  bind_rows(qof_national_prev) %>% 
  mutate(Prevalence = Numerator / Denominator) %>% 
  mutate(lower_CI = binom.wilson(Numerator, Denominator, conf.level = .95)$lower,
         upper_CI = binom.wilson(Numerator, Denominator, conf.level = .95)$upper) %>%
  ungroup()

qof_prev %>% 
  mutate(Condition = paste0(Condition, ' (', Age_group, ')')) %>% 
  select(!c(Condition_code, Age_group)) %>% 
  filter(Type != 'GP') %>% 
  arrange(Condition, Area_Name) %>% 
  toJSON() %>% 
  write_lines(paste0(output_directory, '/qof_prevalence.json'))

qof_prev %>% 
  mutate(Condition = paste0(Condition, ' (', Age_group, ')')) %>% 
  filter(Type != 'GP') %>% 
  select(Condition, Area_Name, Prevalence) %>% 
  arrange(Condition, Area_Name) %>% 
  pivot_wider(names_from = 'Area_Name',
              values_from = 'Prevalence') %>% 
  toJSON() %>% 
  write_lines(paste0(output_directory, '/qof_prevalence_wide.json'))

qof_prev %>% 
  mutate(Condition = paste0(Condition, ' (', Age_group, ')')) %>% 
  filter(Type != 'GP') %>% 
  select(Condition, Area_Name, Prevalence) %>% 
  arrange(Condition, Area_Name) %>% 
  pivot_wider(names_from = 'Area_Name',
              values_from = 'Prevalence') %>%
  rename(group = Condition) %>% 
  write_csv(paste0(output_directory, '/qof_prevalence_wide_test.csv'))

# Chart ideas

# Figure 1 by area

qof_prev %>% 
  filter(Area_Name == 'West Sussex') %>% 
  arrange(desc(Prevalence)) %>% 
  # view()
  # mutate(Condition = factor(Condition)) %>% 
  ggplot(aes(x = Condition,
             y = Prevalence,
             reorder(-Prevalence),
             fill = Condition_group)) +
  geom_bar(stat = 'identity')

# Exact Poisin confidence intervals are calculated using the pois.exact function from the epitools package (see https://www.rdocumentation.org/packages/epitools/versions/0.09/topics/pois.exact for details)

rm(qof_prev_wsx, qof_prev_wsx_gps, qof_prev_wsx_pcns, qof_national_prev)



