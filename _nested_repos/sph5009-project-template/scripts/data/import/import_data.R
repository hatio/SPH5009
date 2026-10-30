# import_data.R
#
# Reads "already processed" data into R. No cleaning or recoding here, see
# scripts/data/process/process_data.R for that.

data_clean = read.csv("data/processed/dummy.csv", stringsAsFactors = FALSE)
