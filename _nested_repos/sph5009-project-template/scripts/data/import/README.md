# scripts/data/import/

Code that reads raw data into R, and nothing else. No cleaning, no
recoding, no filtering, that happens in `scripts/data/process/`.

Keeping import strictly separate from processing means you always have
one clearly identifiable place where raw files are first touched, which
matters when auditing exactly how a sensitive dataset was handled.

## Files

- **`import_data.R`** — reads the raw file(s) from `data/raw` (as specified in `data_paths.R`) into R objects.
- **`verify_data_hash.R`** — checks your local `data/raw` files against the
  checksums recorded in `data_manifest.csv` at the project root. Run this
  *before* `import_data.R`, to confirm you have the correct, unmodified
  data before doing anything else with it.
