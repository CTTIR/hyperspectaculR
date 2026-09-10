# Publish only explicit public evidence and the source files its links reference.
# Run after pkgdown::build_site(): Rscript data-raw/prepare-site-evidence.R [site]
arguments <- commandArgs(trailingOnly = TRUE)
site <- if (length(arguments)) arguments[1L] else "docs"
if (!dir.exists(site)) cli::cli_abort("Build the site before copying evidence.")
public_directories <- c("planning", "R", "tests", "data-raw", "vignettes")
public_files <- unlist(lapply(public_directories, function(directory) {
  list.files(directory, pattern = "[.](R|Rmd|md|csv|txt|svg)$",
             recursive = TRUE, full.names = TRUE)
}), use.names = FALSE)
public_files <- c("ROADMAP.md", public_files)
for (path in public_files) {
  target <- file.path(site, path)
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(path, target, overwrite = TRUE)) {
    cli::cli_abort("Could not copy public source {.path {path}}.")
  }
}
message("Copied public evidence/source files: ", length(public_files))

# pkgdown rewrites Markdown links to .html even for evidence it does not render.
# Point only those unresolved generated links at the copied raw Markdown.
rewritten <- 0L
for (page in list.files(site, "[.]html$", recursive = TRUE, full.names = TRUE)) {
  links <- xml2::xml_attr(xml2::xml_find_all(xml2::read_html(page), "//a[@href]"), "href")
  content <- readLines(page, warn = FALSE)
  for (link in unique(links)) {
    if (is.na(link) || grepl("^([[:alpha:]][[:alnum:]+.-]*:|//|#)", link) ||
        !grepl("[.]html($|[?#])", link)) next
    clean <- sub("[?#].*$", "", link)
    target <- file.path(dirname(page), clean)
    markdown <- sub("[.]html$", ".md", target)
    if (!file.exists(target) && file.exists(markdown)) {
      replacement <- sub("[.]html($|[?#])", ".md\\1", link)
      content <- gsub(paste0('href="', link, '"'),
                       paste0('href="', replacement, '"'), content, fixed = TRUE)
      rewritten <- rewritten + 1L
    }
  }
  writeLines(content, page, useBytes = TRUE)
}
message("Generated evidence links redirected to raw Markdown: ", rewritten)
