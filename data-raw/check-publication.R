# Check repository metadata and local images after building pkgdown.
# Run: Rscript data-raw/check-publication.R [site-directory]
arguments <- commandArgs(trailingOnly = TRUE)
site <- if (length(arguments)) arguments[1L] else "docs"
version <- unname(read.dcf("DESCRIPTION")[1L, "Version"])
citation <- yaml::read_yaml("CITATION.cff")
zenodo <- jsonlite::fromJSON(".zenodo.json")
if (!identical(version, citation$version) || !identical(version, zenodo$version)) {
  cli::cli_abort("Package and citation metadata versions differ.")
}
readme <- paste(readLines("README.md", warn = FALSE), collapse = "\n")
markdown_images <- regmatches(readme, gregexpr("!\\[[^]]*\\]\\(([^)]+)\\)", readme))[[1L]]
markdown_paths <- sub(".*\\]\\(([^)]+)\\)$", "\\1", markdown_images)
html_images <- regmatches(readme, gregexpr('<img[^>]+src="[^"]+"', readme))[[1L]]
html_paths <- sub('.*src="([^"]+)"$', "\\1", html_images)
local_path <- function(path) !grepl("^([[:alpha:]][[:alnum:]+.-]*:|//|#)", path)
paths <- c(markdown_paths, html_paths)
paths <- paths[vapply(paths, local_path, logical(1))]
if (any(!file.exists(paths))) cli::cli_abort("Unresolved README images: {paths[!file.exists(paths)]}.")
message("README local images resolved: ", length(paths))
if (!dir.exists(site)) cli::cli_abort("Build pkgdown before checking site assets: {.path {site}}.")
pages <- list.files(site, "[.]html$", recursive = TRUE, full.names = TRUE)
if (!length(pages)) cli::cli_abort("No built HTML pages found.")
checked <- 0L
for (page in pages) {
  document <- xml2::read_html(page)
  images <- xml2::xml_find_all(document, "//img")
  sources <- xml2::xml_attr(images, "src")
  for (source in sources[!is.na(sources)]) {
    if (!local_path(source)) next
    clean <- utils::URLdecode(sub("[?#].*$", "", source))
    target <- if (startsWith(clean, "/")) file.path(site, substring(clean, 2L)) else
      file.path(dirname(page), clean)
    if (!file.exists(target)) cli::cli_abort("Unresolved image {.val {source}} in {.path {page}}.")
    checked <- checked + 1L
  }
}
message("Built site local images resolved: ", checked, " across ", length(pages), " pages")

# Follow ordinary Markdown and HTML file links, retaining fragments only as
# navigation (this verifies targets exist, not headings within each target).
check_link <- function(link, origin, root) {
  if (is.na(link) || !nzchar(link) || !local_path(link)) return(invisible(NULL))
  clean <- utils::URLdecode(sub("[?#].*$", "", link))
  if (!nzchar(clean)) return(invisible(NULL))
  target <- if (startsWith(clean, "/")) file.path(root, substring(clean, 2L)) else
    file.path(dirname(origin), clean)
  if (!file.exists(target)) cli::cli_abort("Unresolved link {.val {link}} in {.path {origin}}.")
}
check_markdown <- function(path, root) {
  content <- paste(readLines(path, warn = FALSE), collapse = "\n")
  matches <- regmatches(content, gregexpr("\\[[^]]*\\]\\(([^)]+)\\)", content))[[1L]]
  links <- sub(".*\\]\\(([^)]+)\\)$", "\\1", matches)
  for (link in links) check_link(link, path, root)
  length(links)
}
source_markdown <- c("README.md", "ROADMAP.md",
                     list.files("planning", "[.]md$", recursive = TRUE, full.names = TRUE))
source_links <- sum(vapply(source_markdown, check_markdown, integer(1), root = "."))
copied_markdown <- file.path(site, source_markdown[-1L])
if (any(!file.exists(copied_markdown))) {
  cli::cli_abort("Copy public evidence before checking the built site.")
}
evidence_links <- sum(vapply(copied_markdown, check_markdown, integer(1), root = site))
page_links <- 0L
for (page in pages) {
  document <- xml2::read_html(page)
  links <- xml2::xml_attr(xml2::xml_find_all(document, "//a[@href]"), "href")
  for (link in links) check_link(link, page, site)
  page_links <- page_links + length(links)
}
message("Source Markdown links checked: ", source_links,
        "; copied evidence links: ", evidence_links,
        "; built page links: ", page_links)
