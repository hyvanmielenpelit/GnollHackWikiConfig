---
name: gollum_config_internals
description: "Gollum and Sinatra behavior that config.rb, lib/gnollhack_seo.rb and lib/gnollhack_assets.rb depend on: how the config is loaded and merged, how page front matter is parsed, sanitized and shown, what Gollum serves from disk versus the committed ref, view and title quirks, the render lock, the sitemap, and the asset cache policy. Read before changing config.rb, adding a page metadata key, or changing how wiki assets are cached."
---

# Gollum Internals Behind config.rb

Facts about Gollum, gollum-lib and Sinatra that this repository relies on. Gem files are
named by their path inside the gem. To test a change, follow `description_verification`.

## 1. Loading

- `bin/gollum` sets `gollum_path` and `wiki_options` from the command line, then does
  `require File.join(Dir.getwd, cfg)` unless the `--config` value starts with `/`. On
  Windows an absolute `--config` therefore gets the working directory prefixed and fails
  with a `LoadError`: pass it relative, and start Gollum from this folder.
- `config.rb` loads its libraries with `require_relative`, which resolves from the file's
  real path, so it works under both Gollum's `require` and the harness's `load`.
- `Precious::App.set(:wiki_options, hash)` merges: Sinatra's `set` installs a merging setter
  for Hash settings. CLI flags such as `--template-dir` survive, and `config.rb`'s keys win
  where both set one.
- Production passes the wiki path and `--template-dir` as absolute paths.
  `GnollHackAssetCaching::WIKI_ROOT` is expanded once at load, before any render's
  `Dir.chdir`. When `gollum_path` is not set, as in `tools/fast_desc.rb`, it is the working
  directory, as in `bin/gollum`.

## 2. Front Matter

- `Gollum::Filter::YAML` (`gollum-lib/lib/gollum-lib/filter/yaml.rb`) parses a `---`…`---`
  block at the top of a Markdown file into `Gollum::Page#metadata`, with string keys, and
  removes it from the HTML.
- The YAML text first goes through the wiki's HTML sanitizer
  (`gollum-lib/lib/gollum-lib/filter.rb`, `sanitize`): `&` becomes `&amp;`, `<` becomes
  `&lt;`, and CR becomes `&#13;`. So a `>` or `|` block scalar becomes `&gt;` and fails to
  parse; plain and quoted scalars survive; CRLF front matter fails to parse. The wiki is
  safe because its `.gitattributes` stores LF in the index and pages are read from the
  committed ref. `GnollHackSeo::Describer#metadata_description` decodes the entities.
- `Gollum::Page#display_metadata?` (`gollum-lib/lib/gollum-lib/page.rb`) hides the metadata
  table only when every key is `title` or `header_enum`. Once the table is shown,
  `rendered_metadata` (`gollum/lib/gollum/views/page.rb`) renders every key.
- `config.rb` hides the SEO keys in both places: `GnollHackSeoMetadata#display_metadata?`
  (prepended to `Gollum::Page`) and `Precious::Views::Page#rendered_metadata`. To add a key
  the rules read, add it to `GnollHackSeo::METADATA_KEYS`.
- Never set `description` in the wiki-wide `metadata:` option: it would apply to every page.
- A malformed front matter makes Gollum show an errors table, and the heuristic description
  is used.

## 3. What Gollum Serves

- Pages come from the committed content of the served ref. A working-tree edit is
  invisible until it is committed.
- A non-page file such as `/.gollum/css/x.css` is served only if it exists in the committed
  tree of the served ref (`Gollum::File.find`, `gollum-lib/lib/gollum-lib/file.rb`); an
  untracked file answers 404. Once found there, its bytes come from the working tree on
  disk when the served ref is HEAD (`get_disk_reference`), through `show_page_or_file`,
  `show_file` and `send_file` (`gollum/lib/gollum/app.rb`), with `Last-Modified` and no
  `Cache-Control` of Gollum's own.
- So a new theme file must be committed (in production: committed and pulled) before it is
  served, while an edit to a committed file is served from disk and rehashed from disk by
  the asset helper. The asset digest is computed from the same bytes Gollum serves.
- `css: true` is not used: it injects `/custom.css` from the wiki root under a fixed URL with
  no version (`gollum/lib/gollum/views/layout.rb`, `custom_css`).
- Gollum's own assets (`/gollum/assets/app-<sha256>.css`) are Sprockets-fingerprinted.
- A custom `--template-dir` overrides only the templates present in it; the wiki overrides
  only `layout.mustache`.

## 4. Views

- `@page.url_path` includes the extension (`"Home.md"`), so the Home check strips it.
- `Page#title` is the first H1 when `h1_title` is on, else `url_path_title` (the metadata
  title or the file name). It re-parses the page with Nokogiri on every call, so
  `config.rb` memoizes it (`GnollHackTitleMemo`).
- `{{description}}` comes from `Page#description` on page views and from
  `Layout#description` (the site-wide text) on every other view.
- Private methods are invisible to Mustache, which is why `seo_describer` is private.
- `{{#asset_url}}…{{/asset_url}}` is a Mustache lambda on `Layout` (the same form as
  Gollum's `sprockets_asset_path`), so every view has it. Templates pair it with
  `{{^asset_url}}…{{/asset_url}}`, which renders the plain URL when a config lacks the
  helper.

## 5. Rendering

gollum-lib renders inside a block-form `Dir.chdir`, which changes the working directory of
the whole process; two concurrent renders raise "conflicting chdir during another chdir
block". `config.rb` wraps `Gollum::Filter::Render#extract` in a reentrant lock
(`GnollHackSerializedRender`).

## 6. The Sitemap

- Entries use `page.escaped_url_path`, which equals the page's `og:url` path. Home is listed
  first as `/Home.md`; the site root only redirects with 302.
- `README.md` and pages in dot-folders are left out.
- Dates come from one history walk. After a new commit, only the commits since the previous
  build are walked when the new commit descends from it (`repo.descendant_of?`); otherwise
  the full history is.
- One `Rugged::Repository` is opened per rebuild and closed in `ensure`.

## 7. Asset Caching

`lib/gnollhack_assets.rb`, applied by the middleware `GnollHackAssetCaching`, which runs
after `GnollHackCrawlerSupport` has turned HEAD into GET. For a GET answered 200 or 304
under `/.gollum/`, except `/.gollum/templates/`:

| Request | `Cache-Control` |
|---|---|
| `v` equal to the current digest (first 16 hex of SHA-256) | `public, max-age=31536000, immutable` |
| `v` present but different | `no-cache` |
| no `v`, `.css` or `.js` | `no-cache` |
| no `v`, anything else | `public, max-age=604800` |

- `no-cache` still gets a cheap 304, because `send_file` answers `If-Modified-Since`.
- The digest cache is per absolute path, guarded by a Mutex, and refreshed when the file's
  mtime or size changes.
- Paths are URL-decoded and must resolve inside `<wiki>/.gollum` (traversal guard).
- IIS sits in front of production and passed the headers through unchanged in testing;
  verify the live headers after each deployment.

## 8. Known Limits

- `word_cut` drops a complete last word.
- The ingress search looks at nested block quotes too.
- Non-Markdown formats get the site-wide text.
