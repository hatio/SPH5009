# verify_data_hash.R
#
# Confirms that the data files sitting in ./data/ (whether a real folder
# or a symlink, see README.md at the project root) exactly match the
# checksums recorded in data_manifest.csv. This lets anyone confirm they
# have the "same" data as everyone else on the project, without that data
# ever having been uploaded to Git.

library(digest)

source('scripts/data/import/data_paths.R')

if (!dir.exists(data_dir)) {
  stop(
    "No data/ folder found. Place your data there, or create a symlink ",
    "to its real location, see README.md section 3.2."
  )
}

manifest = read.csv(manifest_path, stringsAsFactors = FALSE)

check_one = function(file_name, expected_hash) {
  file_path = file.path(data_dir, file_name)

  if (!file.exists(file_path)) {
    return(data.frame(
      file_name = file_name,
      status = "MISSING",
      detail = paste("Expected file not found at", file_path)
    ))
  }

  actual_hash = digest(file_path, algo = "sha256", file = TRUE)

  if (identical(actual_hash, expected_hash)) {
    status = "OK"
    detail = "Hash matches manifest."
  } else {
    status = "MISMATCH"
    detail = sprintf(
      "Expected %s, got %s. This is NOT the same file others are using.",
      expected_hash, actual_hash
    )
  }

  data.frame(file_name = file_name, status = status, detail = detail)
}

results = do.call(rbind, Map(check_one, manifest$file_name, manifest$expected_sha256))
print(results, row.names = FALSE)

if (any(results$status != "OK")) {
  warning(
    "One or more data files failed verification. Do not proceed with ",
    "analysis until this is resolved; see the table above."
  )
} else {
  message("All data files verified against data_manifest.csv.")
}
