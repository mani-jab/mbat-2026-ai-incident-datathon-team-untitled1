# No network calls and no package installation are performed while rendering.
load_validation_data <- function(project_root = getwd()) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Install jsonlite before rendering.")
  root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  if (!file.exists(file.path(root, "_quarto.yml"))) stop("Render from the project root.")
  folder <- file.path(root, "data", "validation")
  manifest <- file.path(folder, "summary.json")
  if (!file.exists(manifest)) {
    stop("Validation evidence is missing from data/validation.")}  
  s <- jsonlite::fromJSON(manifest)
  if (!isTRUE(s$schema_version == 2)) stop("Re-publish using the updated exporter (evidence version 2).")
  expected <- c("date_audit.csv", "domain_summary.csv", "join_audit.csv", "cleaning_audit.csv", "validation_checks.csv")
  if (!setequal(names(s$csv_md5), expected)) stop("Unexpected or incomplete evidence manifest.")
  paths <- file.path(folder, expected)
  if (any(!file.exists(paths))) stop("One or more evidence CSV files are missing.")
  text_md5 <- function(path) {
    lines <- readLines(path, encoding = "UTF-8", warn = FALSE)
    text <- paste0(paste(lines, collapse = "\n"), "\n")
    tmp <- tempfile(); on.exit(unlink(tmp), add = TRUE)
    writeBin(charToRaw(enc2utf8(text)), tmp)
    unname(tools::md5sum(tmp))
  }
  hashes <- unname(vapply(paths, text_md5, character(1)))
  if (any(hashes != unlist(s$csv_md5[expected], use.names = FALSE))) stop("Evidence files do not match summary.json. Re-publish the complete set; do not edit CSV values manually.")
  tab <- function(name) utils::read.csv(file.path(folder, paste0(name, ".csv")),
    stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8")
  checks <- tab("validation_checks")
  if (!nrow(checks) || !all(checks$passed %in% TRUE)) stop("Evidence checks are missing or failed.")
  domains <- tab("domain_summary")
  if (sum(domains$n_reports) != s$metrics$total_reports) stop("Domain denominator does not reconcile.")
  list(summary = s, date_audit = tab("date_audit"), domain_summary = domains,
    join_audit = tab("join_audit"), cleaning_audit = tab("cleaning_audit"), validation_checks = checks)
}
