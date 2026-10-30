# generate_data_hash.R
#
# Computes SHA-256 checksums for data files and writes (or updates) them
# in data_manifest.csv. Run this once after you first place your data in
# ./data/ (or re-run it deliberately whenever the data legitimately changes),
# then commit the updated data_manifest.csv so others can verify they have
# the same data via verify_data_hash.R.

library(digest)

source('scripts/data/import/data_paths.R')

if (!dir.exists(data_dir)) {
    stop(
        "No data/ folder found. Place your data there, or create a symlink ",
        "to its real location, see README.md section 3.2."
    )
}

# Files to hash: every file in data/
files = list.files(data_dir, recursive = TRUE)

if (length(files) == 0) {
    stop("No files found in ", data_dir, ". Nothing to hash.")
}

new_hashes = sapply(files, function(f) {
    digest(file.path(data_dir, f), algo = "sha256", file = TRUE)
})

new_manifest = data.frame(
    file_name = files,
    expected_sha256 = new_hashes,
    stringsAsFactors = FALSE
)

# if manifest file already exists
if (file.exists(manifest_path)) {
    old_manifest = read.csv(manifest_path, stringsAsFactors = FALSE)

    new_manifest = merge(
        new_manifest
        , old_manifest
        , by = "file_name"
        , all = TRUE
        , suffix = c('', '.old')
    )

    # print warnings for files that hash changed
    if("expected_sha256.old" %in% colnames(new_manifest)){
        response = paste(
            "Hashed changed for files:"
            , paste(with(new_manifest, file_name[expected_sha256 != expected_sha256.old]), collapse = ", ")
            , "Continue to proceed?"
            , sep = "\n"
        )
        # ask if user still wants to proceed with new version of data
        response <- readline(prompt = paste0(response, " [y/n]: "))
    }
    proceed = grepl('^[yY]', response)
} else {
    proceed = TRUE
}

if(proceed){
    new_manifest = new_manifest[ ,c('file_name', 'expected_sha256')]
    write.csv(new_manifest, manifest_path, row.names = FALSE)    
    message(
    "Wrote ", nrow(new_manifest), " file hash(es) to ", manifest_path
    )
    print(new_manifest, row.names = FALSE)
}
