# Exercise the same source() calls as the site workflow in disposable projects.
# Run from the repository root: Rscript data-raw/test-site-evidence.R
(function() {
  source_root <- normalizePath(".", winslash = "/")
  fixture_root <- tempfile("site-evidence-")
  dir.create(fixture_root)
  on.exit(unlink(fixture_root, recursive = TRUE), add = TRUE)
  original_directory <- getwd()
  on.exit(setwd(original_directory), add = TRUE, after = FALSE)

  for (mode in c("development", "release", "explicit")) {
    fixture <- file.path(fixture_root, mode)
    dir.create(fixture)
    for (path in c("DESCRIPTION", "CITATION.cff", ".zenodo.json")) {
      file.copy(file.path(source_root, path), file.path(fixture, path))
    }
    # Pin each fixture to a version of the matching kind, independent of the
    # version currently in the source DESCRIPTION.
    fixture_version <- switch(mode, development = "0.2.0.9000", release = "0.2.0")
    if (!is.null(fixture_version)) {
      description <- readLines(file.path(fixture, "DESCRIPTION"))
      writeLines(sub("^Version:.*", paste("Version:", fixture_version), description),
                 file.path(fixture, "DESCRIPTION"))
      citation <- yaml::read_yaml(file.path(fixture, "CITATION.cff"))
      citation$version <- fixture_version
      yaml::write_yaml(citation, file.path(fixture, "CITATION.cff"))
      zenodo <- jsonlite::fromJSON(file.path(fixture, ".zenodo.json"))
      zenodo$version <- fixture_version
      jsonlite::write_json(zenodo, file.path(fixture, ".zenodo.json"), auto_unbox = TRUE)
    }
    writeLines(c("development:", "  mode: auto"), file.path(fixture, "_pkgdown.yml"))
    for (path in c("planning/evidence", ".github/workflows", "man/figures")) {
      dir.create(file.path(fixture, path), recursive = TRUE)
    }
    for (path in c("README.md", "ROADMAP.md")) {
      writeLines(c("# Fixture", "[Record](planning/evidence/record.md)"), file.path(fixture, path))
    }
    writeLines("# Record", file.path(fixture, "planning/evidence/record.md"))
    writeLines("name: fixture", file.path(fixture, ".github/workflows/minimum-compatibility.yaml"))
    # These copied fixture assets are not rendered or referenced by the HTML.
    for (name in c("logo.svg", paste0("gallery-", c(
      "mandala", "flux", "fusion", "density", "gradient", "quartiles"
    ), ".png"))) writeLines("fixture", file.path(fixture, "man/figures", name))
    destination <- switch(mode, development = "docs/dev", release = "docs", explicit = "custom-site")
    dir.create(file.path(fixture, destination), recursive = TRUE)
    page <- file.path(fixture, destination, "ROADMAP.html")
    writeLines(paste0('<html><body><a href="planning/evidence/record.html#record">Record</a>',
                     '<a href="https://example.org/record.html">External</a></body></html>'), page)
    setwd(fixture)
    scope <- new.env(parent = globalenv())
    scope$commandArgs <- function(trailingOnly = FALSE) {
      if (mode == "explicit") destination else character()
    }
    source(file.path(source_root, "data-raw/prepare-site-evidence.R"), local = scope)
    source(file.path(source_root, "data-raw/check-publication.R"), local = scope)
    links <- xml2::xml_attr(xml2::xml_find_all(xml2::read_html(page), "//a"), "href")
    if (!identical(links, c("planning/evidence/record.md#record", "https://example.org/record.html"))) {
      cli::cli_abort("Evidence rewriting failed for {.val {mode}}.")
    }
    writeLines('<html><body><a href="planning/evidence/missing.md">Missing</a></body></html>', page)
    failure <- tryCatch({
      source(file.path(source_root, "data-raw/check-publication.R"), local = scope)
      NULL
    }, error = identity)
    if (!inherits(failure, "error") || !grepl("Unresolved link", conditionMessage(failure))) {
      cli::cli_abort("Missing evidence was not rejected for {.val {mode}}.")
    }
    setwd(original_directory)
    message("Site evidence fixture passed: ", mode)
  }
})()
