library(easypackages)

libraries(c("readxl", "readr", "plyr", "dplyr", "ggplot2", "png", "tidyverse", "reshape2", "scales", "rgdal", 'rgeos', "tmaptools", 'sp', 'sf', 'maptools', 'leaflet', 'leaflet.extras', 'spdplyr', 'geojsonio', 'rmapshaper', 'jsonlite', 'httr', 'rvest', 'stringr', 'fingertipsR', 'epitools'))

options(scipen = 999)

getwd()
github_repo_dir <- "~/GitHub/pcn_hi_2022_des"
#github_repo_dir <- 'https://raw.githubusercontent.com/psychty/pcn_hi_2022_des/main/'

source_directory <- paste0(github_repo_dir, '/data')
output_directory <- paste0(github_repo_dir, '/outputs')
#output_directory <- paste0('./outputs')

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

# CVD PREVENT ####

time_periods <- c('To March 2020', 'To September 2020', 'To March 2021', 'To September 2021', 'To March 2022', 'To September 2022', 'To March 2023', 'To September 2023', 'To March 2024', 'To September 2024')

# AF prevalence wsx

indicator_x <- 1

# This will attempt to download data for all area types and dates for indicator_x.

af_prevalence <- read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=1')) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=2'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=3'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=4'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=5'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=1'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=2'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=3'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=4'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=5'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=1'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=2'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=3'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=4'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=5'))) %>% 
  rename(Indicator = IndicatorName,
         Sex = CategoryAttribute,
         Note = ValueNote,
         Area_Code = AreaCode,
         Area_Name = AreaName,
         Period = TimePeriodName) %>% 
  filter(Area_Name %in% c('NHS West Sussex CCG', 'NHS East Sussex CCG', 'NHS Brighton and Hove CCG', 'Sussex and East Surrey Health and Care Partnership', 'England', gp_lookup$PCN_Name)) %>% 
  mutate(Period = factor(Period, levels = time_periods))

indicator_x <- 11

hyp_prevalence <- read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=1')) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=2'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=3'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=4'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=5'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=1'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=2'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=3'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=4'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=5'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=1'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=2'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=3'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=4'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=5'))) %>% 
  rename(Indicator = IndicatorName,
         Sex = CategoryAttribute,
         Note = ValueNote,
         Area_Code = AreaCode,
         Area_Name = AreaName,
         Period = TimePeriodName) %>% 
  filter(Area_Name %in% c('NHS West Sussex CCG', 'NHS East Sussex CCG', 'NHS Brighton and Hove CCG', 'Sussex and East Surrey Health and Care Partnership', 'England', gp_lookup$PCN_Name)) %>% 
  mutate(Period = factor(Period, levels = time_periods))

indicator_x <- 8

ckd_prevalence <- read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=1')) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=2'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=3'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=4'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=5'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=1'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=2'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=3'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=4'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=5'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=1'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=2'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=3'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=4'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=5'))) %>% 
  rename(Indicator = IndicatorName,
         Sex = CategoryAttribute,
         Note = ValueNote,
         Area_Code = AreaCode,
         Area_Name = AreaName,
         Period = TimePeriodName) %>% 
  filter(Area_Name %in% c('NHS West Sussex CCG', 'NHS East Sussex CCG', 'NHS Brighton and Hove CCG', 'Sussex and East Surrey Health and Care Partnership', 'England', gp_lookup$PCN_Name)) %>% 
  mutate(Period = factor(Period, levels = time_periods))

indicator_x <- 9

famililal_hypercholesterolaemia_prevalence <- read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=1')) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=2'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=3'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=4'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=5'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=1'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=2'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=3'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=4'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=5'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=1'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=2'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=3'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=4'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=5'))) %>% 
  rename(Indicator = IndicatorName,
         Sex = CategoryAttribute,
         Note = ValueNote,
         Area_Code = AreaCode,
         Area_Name = AreaName,
         Period = TimePeriodName) %>% 
  filter(Area_Name %in% c('NHS West Sussex CCG', 'NHS East Sussex CCG', 'NHS Brighton and Hove CCG', 'Sussex and East Surrey Health and Care Partnership', 'England', gp_lookup$PCN_Name)) %>% 
  mutate(Period = factor(Period, levels = time_periods))

age_sex_table <- af_prevalence %>% 
  bind_rows(ckd_prevalence) %>% 
  bind_rows(hyp_prevalence) %>% 
  # mutate(Prevalence = Numerator / Denominator) %>% 
  # mutate(lower_CI = binom.wilson(Numerator, Denominator, conf.level = .95)$lower,
  #        upper_CI = binom.wilson(Numerator, Denominator, conf.level = .95)$upper) %>%
  rename(Prevalence = Value,
         lower_CI = LowerConfidenceLimit,
         upper_CI = UpperConfidenceLimit) %>% 
  filter(MetricCategoryTypeName == 'Age group') %>% 
  rename(Age_group = MetricCategoryName) %>%
  filter(Period == 'To September 2021') %>% 
  mutate(Label = paste0(trimws(format(Numerator, big.mark = ','), 'both'), ' (', round(Prevalence, 1), '%, ', round(lower_CI, 1), '-', round(upper_CI,1),'%)')) %>%  
  # mutate(Label = paste0(Value, '% (', LowerConfidenceLimit, '-', UpperConfidenceLimit,'% , ', trimws(format(Numerator, big.mark = ','), 'both'), ')')) %>%  
  select(Indicator, Area_Name, Sex, Age_group, Label) %>% 
  pivot_wider(names_from = 'Age_group', 
              values_from = 'Label')

age_sex_table %>% 
  toJSON() %>% 
  write_lines(paste0(output_directory, '/cvd_prevent_prevalence_agesex.json'))

# What is the latest period?

latest_period <- af_prevalence %>% select(Period) %>% unique() %>% arrange(desc(Period)) %>% top_n(1) 

quintile_df <- af_prevalence %>% 
  bind_rows(hyp_prevalence) %>% 
  bind_rows(ckd_prevalence) %>% 
  # mutate(Prevalence = Numerator / Denominator) %>% 
  # mutate(lower_CI = binom.wilson(Numerator, Denominator, conf.level = .95)$lower,
  #        upper_CI = binom.wilson(Numerator, Denominator, conf.level = .95)$upper) %>%
  rename(Prevalence = Value,
         lower_CI = LowerConfidenceLimit,
         upper_CI = UpperConfidenceLimit) %>% 
  filter(MetricCategoryTypeName == 'Deprivation quintile') %>% 
  filter(Period == latest_period$Period) %>% 
  mutate(Quintile = factor(ifelse(MetricCategoryName == '1 - most deprived', 'Proportion_most', ifelse(MetricCategoryName == '2', 'Proportion_q2', ifelse(MetricCategoryName == '3', 'Proportion_q3', ifelse(MetricCategoryName == '4', 'Proportion_q4', ifelse(MetricCategoryName == '5 - least deprived', 'Proportion_least', NA))))), levels = c("Proportion_most", 'Proportion_q2', 'Proportion_q3', 'Proportion_q4', 'Proportion_least'))) %>%
  mutate(Condition = ifelse(IndicatorCode == 'CVDP001AF', 'AF', ifelse(IndicatorCode == 'CVDP001HYP', 'HYP', ifelse(IndicatorCode == 'CVDP001CKD', 'CKD', NA))))

af_quintile_df <- quintile_df %>% 
  filter(Condition == 'AF') %>% 
  mutate(Prevalence = Prevalence / 100,
         lower_CI = lower_CI / 100,
         upper_CI = upper_CI / 100) %>% 
  select(Condition, Area_Name, Quintile, Numerator, Denominator, Prevalence, lower_CI, upper_CI) %>% 
  group_by(Area_Name) %>% 
  nest()

af_quintile_df %>% 
  toJSON() %>% 
  write_lines(paste0(output_directory, '/cvdprevent_af_prevalence.json'))

# anticoagulant treatment ####

indicator_x = 7

af_high_risk_anticoagulant <- read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=1')) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=2'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=3'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=4'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=5'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=1'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=2'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=3'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=4'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=5'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=1'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=2'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=3'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=4'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=5'))) %>% 
  rename(Indicator = IndicatorName,
         Sex = CategoryAttribute,
         Note = ValueNote,
         Area_Code = AreaCode,
         Area_Name = AreaName,
         Period = TimePeriodName) %>% 
  filter(Area_Name %in% c('NHS West Sussex CCG', 'NHS East Sussex CCG', 'NHS Brighton and Hove CCG', 'Sussex and East Surrey Health and Care Partnership', 'England') | Area_Code %in% gp_lookup$PCN_Code) %>% 
  mutate(Period = factor(Period, levels = time_periods))

latest_af_treatment_period <- af_high_risk_anticoagulant %>% select(Period) %>% unique() %>% arrange(desc(Period)) %>% top_n(1) 

af_high_risk_anticoagulant_latest_pcn_view <- af_high_risk_anticoagulant %>% 
  filter(Period == latest_af_treatment_period$Period) %>% 
  filter(MetricCategoryTypeName == 'Sex') %>% 
  rename(Prescription_rate = Value,
         lower_CI = LowerConfidenceLimit,
         upper_CI = UpperConfidenceLimit) %>% 
  select(Sex, Area_Name, Period, Numerator, Denominator, Prescription_rate, lower_CI, upper_CI) 

wsx_af_high_risk_coag <- af_high_risk_anticoagulant_latest_pcn_view %>% 
  filter(Area_Name == 'NHS West Sussex CCG') %>% 
  rename(WSx_lower_CI = lower_CI,
         WSx_upper_CI = upper_CI) %>% 
  select(Sex, WSx_lower_CI, WSx_upper_CI)

England_af_high_risk_coag <- af_high_risk_anticoagulant_latest_pcn_view %>% 
  filter(Area_Name == 'England') %>% 
  rename(Eng_lower_CI = lower_CI,
         Eng_upper_CI = upper_CI) %>% 
  select(Sex, Eng_lower_CI, Eng_upper_CI)

af_treatment_df <- af_high_risk_anticoagulant_latest_pcn_view %>% 
  left_join(wsx_af_high_risk_coag, by = 'Sex') %>% 
  left_join(England_af_high_risk_coag, by = 'Sex') %>% 
  mutate(Significance_national = ifelse(lower_CI > Eng_upper_CI, 'higher', ifelse(upper_CI < Eng_lower_CI, 'lower', 'similar'))) %>% 
  mutate(Significance_wsx = ifelse(lower_CI > WSx_upper_CI, 'higher', ifelse(upper_CI < WSx_lower_CI, 'lower', 'similar'))) %>% 
  mutate(Not_meeting_target = Denominator - Numerator) %>% 
  select(Area_Name, Sex, Period, Numerator, Denominator, Not_meeting_target, Prescription_rate, lower_CI, upper_CI, Significance_wsx, Significance_national)

setdiff(gp_lookup$PCN_Name, af_treatment_df$Area_Name)

# The CVDPREVENT data for pcn names is a bit funky
af_treatment_df %>% 
  mutate(Area_Name = gsub('Aic', 'AIC', Area_Name)) %>% 
  mutate(Area_Name = gsub('Acf', 'ACF', Area_Name)) %>% 
  mutate(Area_Name = gsub(' And ', ' and ', Area_Name)) %>% 
  mutate(Area_Name = gsub(' Of ', ' of ', Area_Name)) %>% 
  mutate(Area_Name = gsub('SHOREHAM AND SOUTHWICK PCN','Shoreham and Southwick PCN', Area_Name)) %>% 
  # mutate(Area_Name_nested = Area_Name) %>% 
  group_by(Area_Name, Sex, Prescription_rate, Significance_national, Significance_wsx) %>% 
  mutate(Prescription_rate = Prescription_rate / 100,
         lower_CI = lower_CI / 100,
         upper_CI = upper_CI / 100) %>% 
  mutate(Sex = ifelse(Sex == 'Male', 'Males', ifelse(Sex == 'Female', 'Females', Sex))) %>% 
  # nest() %>%
  toJSON() %>% 
  write_lines(paste0(output_directory, '/af_treatment_nested.json'))
  
# numerator = patients with af and latest cha2ds2-vasc score 2+ who have a recorded prescription of anticoagulation therapy in the previous six months

# denominator = Total number of patients on the atrial fibrillation register who are deemed at a high risk of stroke (CHA2DS2-VASc score is greater than or equal to 2)

# lets do variation by pcn and sex stacked bars ####

# show prevalence, statistical significance compared with national

# investigate age/sex/ethnicity/deprivation inequalities at ccg level due to small counts and supression.

# Hypertension


indicator_x = 4

hyp_recorded_bp <- read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=1')) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=2'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=3'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=4'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=1&systemLevelID=5'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=1'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=2'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=3'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=4'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=2&systemLevelID=5'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=1'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=2'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=3'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=4'))) %>% 
  bind_rows(read_csv(paste0('https://api.cvdprevent.nhs.uk/indicator/', indicator_x, '/rawDataCSV?timePeriodID=3&systemLevelID=5'))) %>% 
  rename(Indicator = IndicatorName,
         Sex = CategoryAttribute,
         Note = ValueNote,
         Area_Code = AreaCode,
         Area_Name = AreaName,
         Period = TimePeriodName) %>% 
  filter(Area_Name %in% c('NHS West Sussex CCG', 'NHS East Sussex CCG', 'NHS Brighton and Hove CCG', 'Sussex and East Surrey Health and Care Partnership', 'England', gp_lookup$PCN_Name)) %>% 
  mutate(Period = factor(Period, levels = time_periods))

latest_hyp_treatment_period <- hyp_recorded_bp %>% select(Period) %>% unique() %>% arrange(desc(Period)) %>% top_n(1) 


# For adults with hypertension aged under 80, reduce clinic blood pressure to below 140/90 mmHg and ensure that it is maintained below that level. [2019, amended 2022]

# 1.4.21For adults with hypertension aged 80 and over, reduce clinic blood pressure to below 150/90 mmHg and ensure that it is maintained below that level. Use clinical judgement for people with frailty or multimorbidity (see also NICE's guideline on multimorbidity). [2019, amended 2022]


hyp_bp_recorded_latest_pcn_view <- hyp_recorded_bp %>% 
  filter(Period == latest_hyp_treatment_period$Period) %>% 
  filter(MetricCategoryTypeName == 'Sex') %>% 
  rename(BP_recorded_rate = Value,
         lower_CI = LowerConfidenceLimit,
         upper_CI = UpperConfidenceLimit) %>% 
  select(Sex, Period, Area_Name, Numerator, Denominator, BP_recorded_rate, lower_CI, upper_CI) 

wsx_hyp_bp_recorded <- hyp_bp_recorded_latest_pcn_view %>% 
  filter(Area_Name == 'NHS West Sussex CCG') %>% 
  rename(WSx_lower_CI = lower_CI,
         WSx_upper_CI = upper_CI) %>% 
  select(Sex, WSx_lower_CI, WSx_upper_CI)

England_hyp_bp_recorded <- hyp_bp_recorded_latest_pcn_view %>% 
  filter(Area_Name == 'England') %>% 
  rename(Eng_lower_CI = lower_CI,
         Eng_upper_CI = upper_CI) %>% 
  select(Sex, Eng_lower_CI, Eng_upper_CI)

hyp_bp_recorded_df <- hyp_bp_recorded_latest_pcn_view %>% 
  left_join(wsx_hyp_bp_recorded, by = 'Sex') %>% 
  left_join(England_hyp_bp_recorded, by = 'Sex') %>% 
  mutate(Significance_national = ifelse(lower_CI > Eng_upper_CI, 'higher', ifelse(upper_CI < Eng_lower_CI, 'lower', 'similar'))) %>% 
  mutate(Significance_wsx = ifelse(lower_CI > WSx_upper_CI, 'higher', ifelse(upper_CI < WSx_lower_CI, 'lower', 'similar'))) %>% 
  mutate(Not_recorded = Denominator - Numerator) %>% 
  select(Area_Name, Sex, Numerator, Denominator, Not_recorded, BP_recorded_rate, lower_CI, upper_CI, Significance_wsx, Significance_national)

hyp_bp_recorded_df %>% 
  group_by(Area_Name, Sex) %>% 
  nest() %>% 
  toJSON() %>% 
  write_lines(paste0(output_directory, '/hyp_bp_recorded_nested.json'))


# treatment to target for hyp - below and above 80 years.


# Cancer services ####


# Other equalities datasets ####

# download.file('https://www.ons.gov.uk/file?uri=%2fpeoplepopulationandcommunity%2fwellbeing%2fdatasets%2finequalitiesdataaudit%2fjanuary2022/equalitiesaudit250122.xlsx', paste0(github_repo_dir, '/data/equalities_audit.xlsx'), mode = 'wb')

equalities_audit <- read_excel("GitHub/pcn_hi_2022_des/data/equalities_audit.xlsx", 
                               sheet = "Audit", skip = 2)