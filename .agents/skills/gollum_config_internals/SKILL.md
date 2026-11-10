---
name: gollum_config_internals
description: "Gollum and Sinatra behavior that config.rb and the libraries in lib/ depend on: how the config is loaded and merged, how page front matter is parsed, sanitized and shown, what Gollum serves from disk versus the committed ref, view and title quirks, the render lock, the sitemap, the asset cache policy, URL routing (slugs, the page index, rewrites and 301s, wikilinks, the commit check), and the rendered page cache (what is cached, the epoch, what ends an entry). Read before changing config.rb, adding a page metadata key, changing how wiki assets are cached, or changing anything a rendered page depends on."
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
  only `layout.mustache`. Gollum reads the template from disk on every render, so an edit
  shows without a restart (and empties the page cache, section 9).
- A page response does not depend on the request: the same page requested with a
  different `Host`, forwarded-protocol headers, user agent, language, cookies, referrer,
  `Accept-Encoding` or conditional headers gives byte-identical headers and body, and
  Gollum sets no cookie (sessions are off). This is what lets the page cache share one
  response.

## 4. Views

- `@page.url_path` includes the extension (`"Home.md"`), so the Home check strips it. Home
  is served at `/` by the clean URL router (section 8); without the router, Gollum answers
  `/` with a 302 to `/Home.md`.
- `{{canonical_url}}` is `nil` on `Layout` and the page's absolute canonical URL on
  `Page`. `noindex` is defined only on `Page` and is true for a historical version, which
  gets `og:url` but no canonical tag.
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

- Entries are the pages' canonical URLs, from the page index of the commit being listed
  (`GnollHackPageIndexCache.at`), which equal their `og:url`. Home is listed first, as
  `/`. A page outside the index would fall back to `page.escaped_url_path`.
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
- `versioned_url` remembers the digest it returned for each file. `outdated_urls` checks
  those files again and returns how many times a returned digest has gone out of date;
  the page cache's environment token includes it. `cache_control` records nothing, so a
  client cannot grow the list.
- Paths are URL-decoded and must resolve inside `<wiki>/.gollum` (traversal guard).
- IIS sits in front of production and passed the headers through unchanged in testing;
  verify the live headers after each deployment.

## 8. URL Routing

`lib/gnollhack_urls.rb`, wired up in `config.rb`'s last section, "Clean page URLs and the
rendered page cache".

- **Slugs.** Per path segment: strip the extension (last segment), lowercase, transliterate
  `ß æ œ ø ł đ ð þ`, NFKD and drop combining marks, delete apostrophes, turn every run
  outside `[a-z0-9]` into one `-`, trim `-`. `Home.md` is `''` (the site root). A slug is
  permanent once published: never change the derivation without redirects for the old form.
- **Indexed pages** are the committed files with a `Gollum::Markup.extensions` extension
  that are not sub-pages (`_Sidebar`, `_Footer`, `_Header`, matched by prefix as
  `Gollum::Page.valid_page_name?` does) and have no segment starting with `.`: the set
  `Gollum::Wiki#pages` returns, less dot-folders. `valid_page_name?` compiles a regular
  expression per call, so `partition_paths` builds one pattern per index build instead.
- **Fallback pages** keep their escaped file URL and are never redirected: a whole
  collision group, an empty segment, a reserved first segment (`gollum`, `uploads`), or a
  slug equal to a non-page file's path ignoring case (`LICENSE`). `check_urls.rb` exits 1
  on any.
- **Router rules**, after unescaping, squeezing `/` and stripping a trailing `/`:
  passthrough paths (`/gollum/`, `/uploads/`, dot-segments, robots, sitemap) pass; `/`
  rewrites to `Home.md`; `?raw` rewrites an exact slug and passes everything else; an
  exact slug rewrites; a slug in other case or with a trailing slash redirects; a page's
  path, with or without extension, in any case, redirects; everything else passes
  (version URLs `/<file>.md/<sha>`, fallback pages, sub-pages, 404s). A redirect always
  targets a slug or `/`, which rewrite, so there are no chains or loops. The 301 has a
  path `Location` and `max-age=86400`.
- **Gollum's own lookup** (`Gollum::File.find` with `case_insensitive_tag_lookup`) matches
  the file name case-insensitively and folders case-sensitively; the legacy lookup here
  ignores the case of both (exact match first, then a unique case-insensitive one).
  Sinatra ignores one trailing slash.
- **Middleware order**: `GnollHackCrawlerSupport` (HEAD to GET, robots, sitemap) ->
  `GnollHackAssetCaching` -> `GnollHackCleanUrls` -> Gollum. The rewrite replaces
  `PATH_INFO` with the escaped real path, which Gollum serves as before, `?raw` included.
- **`escaped_url_path` is not overridden**: Gollum's tool pages build history, compare,
  edit and raw URLs from it, and its raw route needs the real file name. Tool pages
  therefore link to `.md` URLs, one 301 per click; they are disallowed in `robots.txt`.
- **Wikilinks**: `generate_link` is overridden (prepended to `Gollum::Filter::Tags`, kept
  private) for `kind == :page_present` only, calling `super` with the slug, so Gollum
  still handles `base_path`, anchors and CSS classes; an empty slug renders `href="/"`.
  The `name` argument is always set for present pages, so the link text is unchanged.
- **The commit check** (`GnollHackPageIndexCache.snapshot`), three paths: checked less than
  a second ago, return the cached index; otherwise stat the branch's loose ref file and
  `packed-refs` and, when that signature is unchanged and the last Rugged verification is
  less than 60 seconds old, return; otherwise open the repository with Rugged, resolve the
  ref, rebuild the index if the commit changed, and close. The signature is taken before
  the ref is resolved. The stat check is used only when the ref is a local branch and one
  of the two files exists; a tag, a commit id, reftable storage or a linked worktree
  verify with Rugged on every due check. No repository is kept open: libgit2 keeps pack
  files mapped, which on Windows blocks `git pull` and `git gc`. A failed read keeps the
  previous index; with none, every request goes to Gollum unchanged.
- **Measured costs** (development machine, figures vary by a factor of 3 to 5): middleware
  on an asset path 0.001 ms, on a slug 0.05 ms, a wikilink 0.0005 ms, a due check about
  1 ms (two ref stats, the template folder and the rendered stylesheets), a Rugged
  verification 6 to 22 ms, an index rebuild 25 to 50 ms, a 301 0.55 ms. Gollum renders a
  small page in 125 to 140 ms and the largest in about 3 s. `check_urls.rb --timing`
  guards the per-request figures.
- **View load order**: the section reopens `Precious::Views::Page`, which is only safe
  after `require 'gollum/views/page'` (section 4); it also uses
  `GnollHackAssetCaching::WIKI_ROOT`, so it is the last section of `config.rb`. Nothing in
  it reads the repository at load time, because `tools/fast_desc.rb` loads `config.rb`
  with no wiki.

## 9. Rendered Page Cache

`lib/gnollhack_page_cache.rb` (`GnollHackPageCache::Store`), one instance per process in
`GnollHackRenderedPages`.

- **Cached**: the whole response of a `GET` that the router rewrites, with no query string,
  answered 200 with `text/html`, no `set-cookie` and no `private` or `no-store`. The key is
  the rewritten path. Redirects, 404s, `?raw` and other query strings, version URLs,
  fallback pages, sub-pages, tool pages, images and theme files are never cached.
- **What a page is rendered from**:

  | Input | Where it lives | How a change is noticed |
  |---|---|---|
  | The page, sidebar, footer, the set of pages, the last-edit date | The served commit | The commit check (section 8) |
  | `layout.mustache` and any other file in the template folder | Disk, read on every render | Its file list and each file's stat |
  | The `?v=` in a versioned asset URL | Disk, hashed as it is | `GnollHackAssets.outdated_urls` |
  | `config.rb`, `lib/`, Gollum and its gems | Loaded at startup | A restart, which empties the cache |

- **The epoch** is one counter in `GnollHackPageIndexCache` that grows when the index is
  built for a new commit or the environment token (template files and their stats, the
  outdated count) changes. The store belongs to one epoch: a request with a newer epoch
  empties it; a response is stored only if the request's epoch is still the store's when
  the render returns (an overtaken render is served to its requester and dropped); a
  request with an older epoch renders and touches nothing.
- **The epoch is read before Gollum reads anything** for the request, in
  `GnollHackCleanUrls`, before the rewrite. Gollum reads the ref, the template and the
  stylesheet after that, so a render is never older than its epoch; it can only be newer,
  and then the epoch is about to change and the entry dies with it.
- **Bound**: a cached page outlives a change by at most the one-second check interval (one
  minute if the stat check ever missed a commit).
- **Memory**: bodies are kept as binary strings up to 128 MB in total, least recently used
  dropped first; a larger body is not stored. All pages together are about 40 MB.
- **One render per page at a time**: concurrent requests for an uncached page wait for the
  first one's result. The key's render lock is taken outside the store's lock and wraps
  Gollum's render lock, always in that order.
- **Seeing it**: `x-gnollhack-cache: hit` or `miss` on every cached page response;
  `GNOLLHACK_PAGE_CACHE=0` at startup turns the cache off. `tools/check_cache.rb` tries to
  make it serve stale content.
- **Rule for future changes**: anything new that a page's HTML depends on, other than the
  commit, must change the environment token (`environment_token` in `config.rb`), or it
  is served stale: a template helper that reads another file, a setting read from disk,
  the time of day. Add a `check_cache.rb` check for it.

## 10. Known Limits

- `word_cut` drops a complete last word.
- The ingress search looks at nested block quotes too.
- Non-Markdown formats get the site-wide text.
