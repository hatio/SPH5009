# process_data.R
#
# Cleans and joins the raw objects created in import_data.R.

library(tidyverse)

# import raw data
data_raw = read_csv('data/raw/dummy.csv')

data_clean = 
    data_raw %>%
    na.omit()

data_clean %>%
    write_csv('data/processed/dummy.csv')
