# scripts/data/process/

Code that takes the raw objects created in `scripts/data/import/` and
cleans, recodes, filters, or joins them into analysis-ready datasets.

Anything written out by this folder's scripts (e.g. a cleaned data frame
saved to disk) is a **computed output**, not raw data, and should not be
committed to Git either; see the `.gitignore` notes in the root `README.md`.

## Files

- **`process_data.R`** — cleans and joins `patient_data_raw` and
  `lookup_table_raw` into a single analysis-ready `patient_data_clean`.
