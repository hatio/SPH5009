# explore_data.R
#
# Quick, informal look at the cleaned data. Not final output.

library(tidyverse)

# output directory
outdir = "output/explore"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

# Import cleaned data
source("scripts/data/import/import_data.R")

data_clean %>%
  print()

g = 
    ggplot(data_clean, aes(x = category, y = value)) +
    geom_boxplot()
ggsave(g
    , filename = file.path(outdir, 'boxplot.pdf')
)
