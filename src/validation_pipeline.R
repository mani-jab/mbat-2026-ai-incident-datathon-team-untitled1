# MBAT datathon: sections 6.7-6.9, reusing the previously successful extraction stages.
# Source this file in RStudio. It defines functions; it does not run MongoDB queries.
# Run: section679_results <- run_sections_6_7_to_6_9()
# This is a read-only, descriptive workflow, not a completed assessment answer.
# Default windows are worked-example choices, not assessment requirements.
# Public API references are listed at the end of this file.

s679_required_packages <- c(
  "mongolite", "jsonlite", "dplyr", "tidyr", "tibble", "stringr",
  "textclean", "ggplot2"
)

s679_install_extraction_packages <- function() {
  missing <- s679_required_packages[
    !vapply(s679_required_packages, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing)) {
    install.packages(missing, repos = "https://cloud.r-project.org")
  }
  invisible(missing)
}

s679_check_extraction_packages <- function() {
  missing <- s679_required_packages[
    !vapply(s679_required_packages, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing)) {
    stop("Missing packages: ", paste(missing, collapse = ", "),
         ". Run s679_install_extraction_packages() in the RStudio Console, then retry.",
         call. = FALSE)
  }
  if (utils::packageVersion("dplyr") < "1.1.1") {
    stop("This script needs dplyr >= 1.1.1. Update dplyr outside rendering.", call. = FALSE)
  }
  invisible(TRUE)
}

# Build JSON arrays as R lists so one-element arrays remain arrays.
s679_json <- function(x) {
  as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", digits = NA))
}

s679_date_expression <- function(field) {
  # Do not guess whether numeric timestamps use seconds or milliseconds.
  list(`$cond` = list(
    list(`$in` = list(list(`$type` = paste0("$", field)), list("date", "string"))),
    list(`$convert` = list(input = paste0("$", field), to = "date",
                          onError = NULL, onNull = NULL)),
    NULL
  ))
}

s679_date_stage <- function() {
  list(`$addFields` = list(`_analysis_date` = s679_date_expression("date_published")))
}

s679_window_stage <- function(start, end_exclusive) {
  as_date <- function(x) list(`$convert` = list(
    input = paste0(x, "T00:00:00Z"), to = "date"
  ))
  list(`$match` = list(`$expr` = list(`$and` = list(
    list(`$ne` = list("$_analysis_date", NULL)),
    list(`$gte` = list("$_analysis_date", as_date(start))),
    list(`$lt` = list("$_analysis_date", as_date(end_exclusive)))
  ))))
}

s679_string <- function(field, fallback = NULL) {
  list(`$cond` = list(
    list(`$eq` = list(list(`$type` = paste0("$", field)), "string")),
    paste0("$", field), fallback
  ))
}

s679_domain_expression <- function() {
  list(`$cond` = list(
    list(`$eq` = list(list(`$type` = "$source_domain"), "string")),
    list(`$toLower` = list(`$trim` = list(input = "$source_domain"))),
    NULL
  ))
}

s679_clean_text <- function(x) {
  # Original text is retained separately. This is deliberately light cleaning.
  x[is.na(x)] <- ""
  x <- textclean::replace_html(x)
  x <- textclean::replace_url(x, replacement = " ")
  x <- textclean::replace_contraction(x)
  stringr::str_squish(x)
}

run_sections_6_7_to_6_9 <- function(
    summary_start = "2020-01-01", text_start = "2024-01-01",
    end_exclusive = "2026-09-22", language = "en",
    max_reports = 5000L, max_text_mb = 60, max_join_rows = 100000L,
    project_root = getwd(), export = TRUE) {
  s679_check_extraction_packages()
  if (!identical(language, "en")) {
    stop("This inherited cleaning workflow uses language = 'en'. Other languages need separately validated preprocessing.", call. = FALSE)
  }
  project_root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  if (!file.exists(file.path(project_root, "_quarto.yml"))) {
    stop("Open the team-project RStudio project first; project_root must contain _quarto.yml.", call. = FALSE)
  }
  dates <- suppressWarnings(as.Date(c(summary_start, text_start, end_exclusive)))
  if (anyNA(dates) || dates[1] >= dates[3] || dates[2] >= dates[3]) {
    stop("Use valid YYYY-MM-DD start dates earlier than end_exclusive.", call. = FALSE)
  }
  if (any(c(max_reports, max_text_mb, max_join_rows) <= 0)) {
    stop("Memory limits must be positive.", call. = FALSE)
  }
  env_file <- file.path(project_root, ".Renviron")
  if (file.exists(env_file)) readRenviron(env_file)
  uri <- Sys.getenv("MONGO_URI")
  db <- Sys.getenv("MONGO_DB", unset = "aiidprod")
  if (!nzchar(db)) db <- "aiidprod"
  if (!nzchar(uri)) stop("MONGO_URI is missing. Configure the local .Renviron; do not paste credentials into code.", call. = FALSE)
  reports_conn <- tryCatch(
    mongolite::mongo("reports", db = db, url = uri, verbose = FALSE),
    error = function(e) stop("Could not connect to reports. Check local credentials and authorised network access; do not share the connection URI.", call. = FALSE))
  on.exit(try(reports_conn$disconnect(), silent = TRUE), add = TRUE)
  incidents_conn <- tryCatch(
    mongolite::mongo("incidents", db = db, url = uri, verbose = FALSE),
    error = function(e) stop("Could not connect to incidents. Check local credentials and authorised network access.", call. = FALSE))
  on.exit(try(incidents_conn$disconnect(), silent = TRUE), add = TRUE)
  rm(uri)

  queries <- list()
  started_at <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  agg <- function(conn, stages, label) {
    json <- s679_json(stages)
    if (!jsonlite::validate(json)) stop("Invalid JSON in ", label, call. = FALSE)
    queries[[label]] <<- json
    tryCatch(tibble::as_tibble(conn$aggregate(json)),
      error = function(e) {
        safe_message <- gsub("mongodb(\\+srv)?://[^[:space:]\"\'<>]+", "[REDACTED_URI]", conditionMessage(e))
        stop("Query ", label, " failed: ", safe_message, call. = FALSE)
      })
  }
  numeric_types <- list("int", "long", "double", "decimal")
  date_stage <- s679_date_stage()
  summary_stages <- list(date_stage, s679_window_stage(summary_start, end_exclusive))
  text_stages <- list(
    list(`$match` = list(language = language)), date_stage,
    s679_window_stage(text_start, end_exclusive)
  )

  message("6.7: publication-date audit and source-domain summary (all languages).")
  date_audit <- agg(reports_conn, list(date_stage,
    list(`$group` = list(`_id` = list(
      original_type = list(`$type` = "$date_published"),
      parseable = list(`$ne` = list("$_analysis_date", NULL))
    ), n = list(`$sum` = 1))),
    list(`$project` = list(`_id` = 0, bson_type = "$_id.original_type",
                           parseable = "$_id.parseable", n = 1))
  ), "date_audit")
  domain_summary <- agg(reports_conn, c(summary_stages, list(
    list(`$group` = list(`_id` = s679_domain_expression(), n_reports = list(`$sum` = 1))),
    list(`$project` = list(`_id` = 0,
      source_domain = list(`$ifNull` = list("$_id", "(missing or invalid)")), n_reports = 1))
  )), "section67_domains")
  if (!nrow(domain_summary)) stop("No reports in the section 6.7 date window. Inspect date fields/settings.", call. = FALSE)
  domain_summary <- domain_summary |>
    dplyr::mutate(source_domain = dplyr::if_else(
      !nzchar(source_domain), "(missing or invalid)", source_domain
    )) |>
    dplyr::group_by(source_domain) |>
    dplyr::summarise(n_reports = sum(n_reports), .groups = "drop") |>
    dplyr::mutate(denominator_reports = sum(n_reports),
                  percent_of_all_reports = 100 * n_reports / denominator_reports) |>
    dplyr::arrange(dplyr::desc(n_reports), source_domain)
  if (!nrow(domain_summary)) stop("No reports in the section 6.7 date window. Inspect date_audit/date settings.", call. = FALSE)

  # The 6.7 output counts documents. Check its keys separately from the narrower corpus.
  summary_key_audit <- agg(reports_conn, c(summary_stages, list(
    list(`$group` = list(`_id` = "$report_number", n = list(`$sum` = 1))),
    list(`$match` = list(n = list(`$gt` = 1))),
    list(`$project` = list(`_id` = 0, report_number = "$_id", n = 1))
  )), "section67_repeated_report_numbers")
  # Retain, rather than hide, repeated keys: report-document counts are still labelled as such.
  if (nrow(summary_key_audit)) warning("Repeated report_number values in the 6.7 window; inspect section67_repeated_report_numbers before describing counts as distinct articles.")

  message("6.8: define the English-report corpus, check size, and validate joins.")
  preflight <- agg(reports_conn, c(text_stages, list(
    list(`$group` = list(`_id` = NULL, n_reports = list(`$sum` = 1),
      invalid_id_type = list(`$sum` = list(`$cond` = list(
        list(`$in` = list(list(`$type` = "$report_number"), numeric_types)), 0, 1))),
      body_bytes = list(`$sum` = list(`$strLenBytes` = s679_string("plain_text", "")))
    )), list(`$project` = list(`_id` = 0, n_reports = 1, invalid_id_type = 1, body_bytes = 1))
  )), "text_corpus_preflight")
  if (!nrow(preflight)) stop("No reports match the chosen language and text date window.", call. = FALSE)
  if (preflight$invalid_id_type[1] > 0) stop("Selected reports contain missing/non-numeric IDs. Investigate; this script will not silently discard them.", call. = FALSE)
  if (preflight$n_reports[1] > max_reports || preflight$body_bytes[1] > max_text_mb * 1024^2) {
    stop(sprintf("Safety stop: %s eligible reports and %.1f MB of raw bodies. No text was truncated. Use a justified narrower window or a larger validated batch workflow.",
                 preflight$n_reports[1], preflight$body_bytes[1] / 1024^2), call. = FALSE)
  }
  corpus <- agg(reports_conn, c(text_stages, list(
    list(`$project` = list(`_id` = 0, report_number = 1,
      report_title = s679_string("title", ""), source_domain = s679_domain_expression(),
      url = s679_string("url", ""), date_published = "$_analysis_date",
      plain_text = s679_string("plain_text"), raw_text_type = list(`$type` = "$plain_text"))),
    list(`$sort` = list(report_number = 1))
  )), "selected_reports")
  required <- c("report_number", "report_title", "source_domain", "url", "date_published", "plain_text", "raw_text_type")
  for (name in setdiff(required, names(corpus))) corpus[[name]] <- NA_character_
  if (nrow(corpus) != preflight$n_reports[1]) stop("Selected row count changed between queries. Re-run; this is not a transactionally frozen database snapshot.", call. = FALSE)
  if (!is.numeric(corpus$report_number) || anyNA(corpus$report_number) ||
      any(!is.finite(corpus$report_number)) || any(corpus$report_number != floor(corpus$report_number)) ||
      any(corpus$report_number <= 0) || any(corpus$report_number >= 2^53) || anyDuplicated(corpus$report_number)) {
    stop("Selected report IDs are missing, invalid, or duplicated. Resolve before text analysis.", call. = FALSE)
  }


  selected_report_duplicates <- agg(reports_conn, list(
    list(`$match` = list(report_number = list(`$in` = as.list(corpus$report_number)))),
    list(`$group` = list(`_id` = "$report_number", n = list(`$sum` = 1))),
    list(`$match` = list(n = list(`$gt` = 1))),
    list(`$project` = list(`_id` = 0, report_number = "$_id", n = 1))
  ), "selected_report_key_uniqueness")
  if (nrow(selected_report_duplicates)) stop("A selected report_number is duplicated elsewhere in the database. Resolve the key before joining.", call. = FALSE)

  links <- agg(reports_conn, c(text_stages, list(
    list(`$project` = list(`_id` = 0, report_number = 1)),
    list(`$lookup` = list(from = "incidents", localField = "report_number",
                          foreignField = "reports", as = "incident")),
    list(`$addFields` = list(`_matched_count` = list(`$size` = "$incident"))),
    list(`$project` = list(`_id` = 0, report_number = 1, `_matched_count` = 1,
      "incident.incident_id" = 1, "incident.title" = 1)),
    list(`$unwind` = list(path = "$incident", preserveNullAndEmptyArrays = TRUE)),
    list(`$project` = list(`_id` = 0, report_number = 1,
      incident_id = list(`$ifNull` = list("$incident.incident_id", NULL)),
      incident_title = list(`$ifNull` = list("$incident.title", "")),
      incident_id_type = list(`$type` = "$incident.incident_id"),
      matched_count = "$_matched_count")),
    list(`$limit` = as.integer(max_join_rows + 1L))
  )), "section68_server_join")
  if (nrow(links) > max_join_rows) stop("Join size guard exceeded. No truncated join is valid for final findings.", call. = FALSE)
  if (!"incident_id" %in% names(links)) links$incident_id <- NA_real_
  if (all(is.na(links$incident_id))) links$incident_id <- rep(NA_real_, nrow(links))
  if (any(links$matched_count > 0 &
          !links$incident_id_type %in% c("int", "long", "double", "decimal"))) {
    stop("A matched incident has a missing/null or unsupported ID type; investigate the linkage.", call. = FALSE)
  }
  if (!is.numeric(links$incident_id) || any(!is.na(links$incident_id) &
      (!is.finite(links$incident_id) | links$incident_id <= 0 | links$incident_id != floor(links$incident_id)))) {
    stop("Invalid matched incident IDs.", call. = FALSE)
  }
  if (!setequal(corpus$report_number, links$report_number)) stop("Join report IDs do not match the selected corpus; check database changes.", call. = FALSE)
  duplicate_pairs <- links |>
    dplyr::count(report_number, incident_id, name = "n") |>
    dplyr::filter(n > 1)
  if (nrow(duplicate_pairs)) stop("Duplicate report-incident pairs found; do not simply delete these without investigating incident records.", call. = FALSE)
  matched_ids <- unique(links$incident_id[!is.na(links$incident_id)])
  if (length(matched_ids)) {
    selected_incident_duplicates <- agg(incidents_conn, list(
      list(`$match` = list(incident_id = list(`$in` = as.list(matched_ids)))),
      list(`$group` = list(`_id` = "$incident_id", n = list(`$sum` = 1))),
      list(`$match` = list(n = list(`$gt` = 1))),
      list(`$project` = list(`_id` = 0, incident_id = "$_id", n = 1))
    ), "selected_incident_key_uniqueness")
    if (nrow(selected_incident_duplicates)) stop("A selected incident_id is duplicated in the database. Resolve before interpretation.", call. = FALSE)
  }
  linkage_per_report <- links |>
    dplyr::group_by(report_number) |>
    dplyr::summarise(n_linked_incidents = dplyr::n_distinct(incident_id, na.rm = TRUE), .groups = "drop")
  join_audit <- tibble::tibble(
    metric = c("Eligible reports", "Matched reports", "Unmatched reports",
               "Reports linked to multiple incidents", "Matched-report percent", "Joined rows"),
    value = c(nrow(corpus), sum(linkage_per_report$n_linked_incidents > 0),
              sum(linkage_per_report$n_linked_incidents == 0),
              sum(linkage_per_report$n_linked_incidents > 1),
              100 * mean(linkage_per_report$n_linked_incidents > 0), nrow(links))
  )

  # R-side alternative is a small validation demo ONLY, on the same report IDs.
  demo_ids <- head(corpus$report_number, 20L)
  demo_query <- s679_json(list(reports = list(`$in` = as.list(demo_ids))))
  queries$section68_demo_incidents <- demo_query
  if (incidents_conn$count(demo_query) > 2000) stop("R-side demo would fetch too many incidents.", call. = FALSE)
  demo_incidents <- tibble::as_tibble(incidents_conn$find(
    query = demo_query, fields = '{"_id":0,"incident_id":1,"reports":1}'
  ))
  raw_map <- tibble::tibble(report_number = double(), incident_id = double())
  if (nrow(demo_incidents)) {
    if (!all(c("incident_id", "reports") %in% names(demo_incidents))) stop("R-side incident structure is unexpected.", call. = FALSE)
    raw_map <- demo_incidents |>
      tidyr::unnest_longer(reports, values_to = "report_number") |>
      dplyr::filter(report_number %in% demo_ids) |>
      dplyr::select(report_number, incident_id)
  }
  repeated_array_refs <- raw_map |>
    dplyr::count(report_number, incident_id, name = "n") |>
    dplyr::filter(n > 1)
  r_pairs <- tibble::tibble(report_number = demo_ids) |>
    dplyr::left_join(dplyr::distinct(raw_map), by = "report_number")
  server_pairs <- links |>
    dplyr::filter(report_number %in% demo_ids) |>
    dplyr::select(report_number, incident_id) |>
    dplyr::distinct()
  join_agrees <- nrow(dplyr::anti_join(r_pairs, server_pairs, by = c("report_number", "incident_id"))) == 0 &&
    nrow(dplyr::anti_join(server_pairs, r_pairs, by = c("report_number", "incident_id"))) == 0
  if (!join_agrees) stop("MongoDB and R-side demo joins disagree. Investigate before continuing.", call. = FALSE)

  message("6.9: preserve originals, clean text, and audit missing/duplicate bodies.")
  reports_clean <- corpus |>
    dplyr::rename(plain_text_original = plain_text) |>
    dplyr::mutate(text_clean = s679_clean_text(plain_text_original),
      original_characters = nchar(plain_text_original, type = "chars"),
      cleaned_characters = nchar(text_clean, type = "chars"),
      text_group = match(text_clean, unique(text_clean)))
  duplicate_text_groups <- reports_clean |>
    dplyr::filter(nzchar(text_clean)) |>
    dplyr::group_by(text_group) |>
    dplyr::summarise(n_reports = dplyr::n(),
      report_numbers = paste(report_number, collapse = ", "), .groups = "drop") |>
    dplyr::filter(n_reports > 1) |>
    dplyr::arrange(dplyr::desc(n_reports))
  cleaning_audit <- tibble::tibble(
    metric = c("Reports selected", "Missing or non-string original bodies",
      "Original bodies empty/whitespace only", "Usable cleaned bodies",
      "Non-empty originals becoming empty", "Exact-duplicate cleaned-body groups"),
    value = c(nrow(reports_clean), sum(is.na(reports_clean$plain_text_original)),
      sum(!is.na(reports_clean$plain_text_original) & !nzchar(stringr::str_squish(reports_clean$plain_text_original))),
      sum(nzchar(reports_clean$text_clean)),
      sum(!is.na(reports_clean$plain_text_original) & nzchar(stringr::str_squish(reports_clean$plain_text_original)) & !nzchar(reports_clean$text_clean)),
      nrow(duplicate_text_groups))
  )
  cleaning_examples <- reports_clean |>
    dplyr::mutate(change_size = abs(original_characters - cleaned_characters)) |>
    dplyr::arrange(dplyr::desc(change_size)) |>
    dplyr::select(report_number, report_title, original_characters, cleaned_characters,
                  plain_text_original, text_clean) |>
    dplyr::slice_head(n = 10)

  result <- list(
    settings = list(summary_start = summary_start, text_start = text_start,
      end_exclusive = end_exclusive, language = language,
      note = "Worked-example windows retained from the previous successful run; not mandated assessment populations."),
    extraction_started_utc = started_at,
    extraction_finished_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    date_audit = date_audit, domain_summary = domain_summary,
    section67_repeated_report_numbers = summary_key_audit,
    join_audit = join_audit, join_agreement = join_agrees,
    r_join_demo_pairs = r_pairs, repeated_array_references_demo = repeated_array_refs,
    report_incident_map = links, reports_clean = reports_clean,
    cleaning_audit = cleaning_audit, cleaning_examples = cleaning_examples,
    duplicate_text_groups = duplicate_text_groups, queries = queries,
    package_versions = vapply(s679_required_packages,
      function(p) as.character(utils::packageVersion(p)), character(1))
  )
  attr(result, "extractor_file") <- "src/validation_pipeline.R"
  if (export) {
    parent <- file.path(project_root, ".local-data", "sections-6-7-to-6-9")
    dir.create(parent, recursive = TRUE, showWarnings = FALSE)
    out <- tempfile(pattern = paste0(format(Sys.time(), "%Y%m%d-%H%M%S"), "-"), tmpdir = parent)
    dir.create(out)
    result$output_directory <- normalizePath(out, winslash = "/")
    # This is a private working copy containing article bodies. NEVER commit it.
    saveRDS(result, file.path(out, "local_results.rds"))
    message("Private working data: ", result$output_directory)
  }
  message("Sections 6.7-6.9 calculated. Inspect cleaning_examples; then publish the aggregate evidence.")
  result
}
