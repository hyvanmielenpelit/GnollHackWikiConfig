# GnollHack Wiki Config

This repository contains the [Gollum](https://github.com/gollum/gollum) configuration for the [GnollHack wiki](https://wiki.gnollhack.com/).

The wiki content itself lives in its own repository, [GnollHackWiki](https://github.com/hyvanmielenpelit/GnollHackWiki). That repository also holds the layout template and the theme (`.gollum/templates/`, `.gollum/css/`, `.gollum/fonts/` and `.gollum/images/`).

## Contents

[`config.rb`](config.rb) is loaded by Gollum at startup. It:

- **Sets the wiki options**: uses the `rugged` Git adapter, enables uploads, uses the first `<h1>` as the page title, resolves links case-insensitively, renders math with KaTeX, turns Mermaid off (no page uses it, and it would load its script on every page), names the wiki "GnollHack Wiki", disables editing, and does not follow renames in the History view.
- **Serializes Markdown rendering**: gollum-lib renders each page inside a block-form `Dir.chdir`, so two concurrent renders can fail with "conflicting chdir during another chdir block". A reentrant lock lets one render step run at a time.
- **Supports crawlers**: answers `HEAD` requests as `GET` without a body, and serves `/robots.txt` and `/sitemap.xml`. The sitemap lists every page with the date of its last commit, under its canonical URL, Home first as the site root `/`. It is rebuilt after each new commit, walking only the commits since the previous build.
- **Versions theme assets**: adds the `{{#asset_url}}…{{/asset_url}}` template helper, which turns a `/.gollum/` path into a URL with `?v=<content hash>`, so a changed stylesheet gets a new URL without being renamed. Files under `/.gollum/` get `Cache-Control` headers: `immutable` for a URL with the current hash, `no-cache` (revalidate) for other CSS and JavaScript, and one week for fonts and images, which take a new file name when their content changes. A file is hashed again when its modification time or size changes, so a theme change pulled into the wiki applies within a second without a restart, also to cached pages. The rules are in [`lib/gnollhack_assets.rb`](lib/gnollhack_assets.rb).
- **Adds SEO template variables**: `{{page_title}}` and `{{description}}`, used by `.gollum/templates/layout.mustache` in the wiki repository. A page can set its own description with a `description:` key in its YAML front matter, which Gollum then leaves out of the page's metadata table. Otherwise the description comes from a page's ingress, caution note, entry header, link list, first usable paragraph (within the first section, on a page that opens with an H2) or opening list. Legal notices, side notes and sentences that depend on surrounding text are skipped. Text is fitted to 160 characters at a sentence or fact boundary, and pages with nothing usable get the site-wide description. The rules are in [`lib/gnollhack_seo.rb`](lib/gnollhack_seo.rb).
- **Serves clean page URLs**: every page is served at a lowercase, hyphenated slug of its file path with no extension, such as `/guides/gnollhack-gnoll-overseer-and-gnollbench-for-software-engineers` for `Guides/GnollHack, Gnoll Overseer, and GnollBench for Software Engineers.md`, and Home at `/`. No page file is renamed: a slug request is rewritten to the page's real path before Gollum sees it, so titles, headings and descriptions still come from the page itself. Old URLs (the file path, with or without its extension, in any letter case, with or without a trailing slash) answer a single 301 to the slug. Wikilinks, `og:url`, `<link rel="canonical">` and the sitemap use the slug. A page whose slug would collide with another page's, has no usable characters in a path segment, starts with `gollum` or `uploads`, or equals a file's path keeps its file URL. Sub-pages, Gollum's tool pages, raw and version URLs, images and theme files are unchanged. [`tools/check_urls.rb`](tools/check_urls.rb) lists every page's URL and the fallbacks; `--crawl` checks every page through the real app, and `--timing` measures the routing layer. The rules are in [`lib/gnollhack_urls.rb`](lib/gnollhack_urls.rb).
- **Caches rendered pages**: keeps the whole response of each page served at its canonical URL in memory, and answers the next request for it without rendering. The cache is emptied within a second of a new commit on the served branch, an edit to the template folder, or an edit to a stylesheet whose versioned URL is in a page; nothing is written to disk, and a restart starts empty. Each cached page response carries `x-gnollhack-cache: hit` or `miss`. Set `GNOLLHACK_PAGE_CACHE=0` before starting Gollum to turn the cache off. [`tools/check_cache.rb`](tools/check_cache.rb) tries to make it serve stale content in a throwaway clone of the wiki. The store is in [`lib/gnollhack_page_cache.rb`](lib/gnollhack_page_cache.rb).

## Files

- [`config.rb`](config.rb): the wiki options and the glue that connects the libraries to Gollum.
- [`lib/`](lib/): the description rules, the asset versioning, the clean page URLs and the rendered page store, as plain Ruby that does not depend on Gollum.
- [`test/`](test/): unit tests for the four libraries.
- [`tools/`](tools/): scripts that render every wiki page and dump its description and title, for checking a change to the description rules, check every page's URL, and check the page cache. They write their output outside the repository.

## Usage

Gollum 6 with the `rugged` adapter (`gollum-rugged_adapter` gem) is required.

Deploy the **whole** folder, not just `config.rb`: `config.rb` loads the files in `lib/`, and Gollum fails at startup with a `LoadError` without them.

Start Gollum from this folder on a clone of the wiki repository, with the wiki's template directory:

```bash
cd /path/to/GnollHackWikiConfig
gollum --config config.rb /path/to/GnollHackWiki --template-dir /path/to/GnollHackWiki/.gollum/templates/
```

Pass `--config` relative to the current folder: on Windows, Gollum prefixes the working directory to the value, so an absolute path fails. Pass the wiki path as an absolute path. The options in `config.rb` are merged into the command-line options, so flags such as `--template-dir` still apply, and the values in `config.rb` win where both set one.

When deploying a change that touches both repositories, deploy this folder and restart Gollum first, then pull the wiki. The template falls back when a helper is missing: to unversioned asset URLs, and to the file-path `og:url` with no canonical tag. So if the wiki is pulled first, pages keep their old `og:url` and get no canonical tag until the config is live, but nothing breaks.

The crawler and SEO settings assume the wiki is served at `https://wiki.gnollhack.com`. Change `SITE_URL` in `config.rb` to serve it elsewhere.

## Tests

From the repository root:

```bash
ruby -Ilib test/test_gnollhack_seo.rb
ruby -Ilib test/test_gnollhack_assets.rb
ruby -Ilib test/test_gnollhack_urls.rb
ruby -Ilib test/test_gnollhack_page_cache.rb
```

## Related Repositories

- [GnollHackWiki](https://github.com/hyvanmielenpelit/GnollHackWiki): the wiki content, layout template and theme.
- [GnollHack](https://github.com/hyvanmielenpelit/GnollHack): the game's source code.

## License

This repository is licensed under the [MIT License](LICENSE). The wiki content in the GnollHackWiki repository has its own license.
