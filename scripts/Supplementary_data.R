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
  # bind_rows(famililal_hypercholesterolaemia_prevalence) %>% 
  filter(MetricCategoryTypeName == 'Age group') %>% 
  rename(Age_group = MetricCategoryName) %>%
  filter(Period == 'To September 2021') %>% 
  mutate(Label = ifelse(IndicatorCode == 'CVDP002FH', paste0(trimws(format(Numerator, big.mark = ','), 'both'), ' (', Value, ' per 1,000, ', LowerConfidenceLimit, '-', UpperConfidenceLimit,' per 1,000)'), paste0(trimws(format(Numerator, big.mark = ','), 'both'), ' (', Value, '%, ', LowerConfidenceLimit, '-', UpperConfidenceLimit,'%)'))) %>%  
  # mutate(Label = paste0(Value, '% (', LowerConfidenceLimit, '-', UpperConfidenceLimit,'% , ', trimws(format(Numerator, big.mark = ','), 'both'), ')')) %>%  
  select(Indicator, Area_Name, Sex, Age_group, Label) %>% 
  pivot_wider(names_from = 'Age_group', 
              values_from = 'Label')

age_sex_table %>% 
  toJSON() %>% 
  write_lines(paste0(output_directory, '/cvd_prevent_prevalence_agesex.json'))


# What is the latest period?

latest_period <- af_prevalence %>% select(Period) %>% unique() %>% arrange(desc(Period)) %>% top_n(1) 

af_prevalence %>% 
  filter(MetricCategoryTypeName == 'Sex') %>% 
  # filter(Area_Name == 'NHS West Sussex CCG') %>%
  filter(Sex == 'Persons') %>% 
  filter(Period == latest_period$Period) %>% 
  select(Area_Name, Numerator, Denominator, Value, LowerConfidenceLimit, UpperConfidenceLimit)

af_prevalence %>% 
  filter(MetricCategoryTypeName == 'Deprivation quintile') %>% 
  filter(Period == latest_period$Period) %>% 
  mutate(Quintile = factor(MetricCategoryName, levels = c('1 - most deprived', '2', '3', '4','5 - least deprived'))) %>% 
  select(Area_Name, Numerator, Denominator, Quintile, Value, LowerConfidenceLimit, UpperConfidenceLimit) %>% 
  ggplot(aes(x = Area_Name,
             y = Value,
             fill = Quintile)) +
  geom_bar(position = 'dodge',
           stat = 'identity')

  

af_prevalence %>% 
  filter(MetricCategoryTypeName == 'Deprivation quintile') %>% 
  mutate(Value = Value / 100) %>% 
  filter(Period == latest_period$Period) %>% 
  mutate(Quintile = factor(ifelse(MetricCategoryName == '1 - most deprived', 'Proportion_most', ifelse(MetricCategoryName == '2', 'Proportion_q2', ifelse(MetricCategoryName == '3', 'Proportion_q3', ifelse(MetricCategoryName == '4', 'Proportion_q4', ifelse(MetricCategoryName == '5 - least deprived', 'Proportion_least', NA))))), levels = c("Proportion_most", 'Proportion_q2', 'Proportion_q3', 'Proportion_q4', 'Proportion_least'))) %>% 
  select(Area_Name, Quintile, Value) %>%
  pivot_wider(names_from = 'Quintile',
              values_from = 'Value') %>% 
  mutate(Area_Name = factor(Area_Name, levels = c('NHS West Sussex CCG', 'NHS East Sussex CCG', 'NHS Brighton and Hove CCG', 'Sussex and East Surrey Health and Care Partnership', 'England'))) %>% 
  arrange(Area_Name) %>% 
  write.csv(., paste0(output_directory,'/cvd_prevent_prevalence_wide.csv'), row.names = FALSE)


# unique(af_prevalence$MetricCategoryName)






af_prevalence_age <- af_prevalence %>% 
  filter(MetricCategoryTypeName == 'Age group',
         Sex == 'Persons')


unique(af_prevalence$MetricCategoryTypeName)



af_prevalence_sex %>% 
  
  


# directly age-standardised prevalence estimates for each deprivation group

# hypertension case finding

cvd_prevent_hyp <- read_csv('https://api.cvdprevent.nhs.uk/indicator/4/rawDataCSV?timePeriodID=2&systemLevelID=4')

unique(cvd_prevent$IndicatorName)


# Cancer services ####


# Other equalities datasets ####

# download.file('https://www.ons.gov.uk/file?uri=%2fpeoplepopulationandcommunity%2fwellbeing%2fdatasets%2finequalitiesdataaudit%2fjanuary2022/equalitiesaudit250122.xlsx', paste0(github_repo_dir, '/data/equalities_audit.xlsx'), mode = 'wb')

equalities_audit <- read_excel("GitHub/pcn_hi_2022_des/data/equalities_audit.xlsx", 
                               sheet = "Audit", skip = 2)
