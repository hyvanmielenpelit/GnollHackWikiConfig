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

## 7. HTTP Caching

`lib/gnollhack_http_caching.rb` (`GnollHackHttpCaching.cache_control`), applied to every
GET response by the middleware `GnollHackAssetCaching`, which runs after
`GnollHackCrawlerSupport` has turned HEAD into GET. It sees `PATH_INFO` as the client sent
it, before `GnollHackCleanUrls` rewrites a slug. First matching row wins; "served" is 200,
206 or 304:

| # | Request path | Status | `Cache-Control` | Replaces an existing one |
|---|---|---|---|---|
| 1 | Under `/.gollum/`, except `/.gollum/templates/` | served | `GnollHackAssets.cache_control`, below | yes |
| 2 | Under `/gollum/assets/`, last segment matches `-[0-9a-f]{64}\.[A-Za-z0-9]+\z` (Sprockets) | served | `public, max-age=31536000, immutable` | yes |
| 3 | Under `/gollum/assets/`, `.css` or `.js` | served | `no-cache` | yes |
| 4 | Under `/gollum/assets/`, anything else (KaTeX fonts) | served | `public, max-age=604800` | yes |
| 5 | Not under `/gollum/`, extension in `STATIC_EXTENSIONS`, `content-type` not `text/html` | served | `public, max-age=86400, s-maxage=604800` | yes |
| 6 | A path of rows 1 to 5 (row 5 without the `content-type` test) | not served | `no-cache` | yes |
| 7 | Anything else: pages, tool pages, `?raw`, 404s, an undecodable path | any | `no-cache` | no |

Row 1, `lib/gnollhack_assets.rb`:

| Request | `Cache-Control` |
|---|---|
| `v` equal to the current digest (first 16 hex of SHA-256) | `public, max-age=31536000, immutable` |
| `v` present but different | `no-cache` |
| no `v`, `.css` or `.js` | `no-cache` |
| no `v`, anything else | `public, max-age=604800` |

- **Gollum sets no `Cache-Control` of its own** on pages, `send_file` files or
  `Rack::Static` assets, and Front Door caches a response without one for one to three
  days on a caching route. A response this middleware skipped would be frozen at the edge.
- Row 7 keeps a value a response already has: the router's 301 (`public, max-age=86400`).
  `/robots.txt` and `/sitemap.xml` are answered by `GnollHackCrawlerSupport` outside this
  middleware, with `public, max-age=3600`.
- Row 5's `content-type` test keeps a page out of it: `Foo.png.md` is served at `/Foo.png`
  as `text/html`. `STATIC_EXTENSIONS` is compared lowercased on the decoded last segment,
  and covers `/uploads/` and the root `/favicon.ico`.
- Gollum's `/gollum/assets/*` route shortens `PATH_INFO` in place (`sub!`), so the
  middleware copies the path before calling down.
- Pages get `no-cache`, not `no-store`: Front Door treats both as uncacheable, and
  `no-cache` keeps pages in the browser's back/forward cache.
- Cached pages pass through the middleware on every hit; the store keeps the headers as
  Gollum returned them.
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

- **Slugs.** A slug is a page's decoded URL title, in MediaWiki's form: strip the extension
  with `%r{\.[^./]+\z}` (not `File.basename`/`File.extname`, which on Windows turn `A:B.md`
  into `B.md`), and per segment turn every run of spaces and underscores into one `_` and
  trim `_`. Letter case follows the file name, also the first letter (`iOS_and_macOS_Version`,
  where MediaWiki would capitalize); every other character is kept. `Home.md` is `''` (the
  site root). For a page without spaces the slug equals Gollum's own extensionless URL, so
  those URLs were already in use. A slug is permanent once published: never change the
  derivation without redirects for the old form.
- **`url_path`** writes a slug in a URL the way MediaWiki's `wfUrlencode` does:
  `ERB::Util.url_encode`, then `; @ $ ! * ( ) , /` back to literal, so `'` is `%27` and
  non-ASCII is UTF-8 percent-encoded and the result is always ASCII. Two exceptions to
  MediaWiki: `:` stays `%3A` and a final `.` is written `%2E`, because wikilink `href`s pass
  through `Pathname#cleanpath`, which on Windows cuts at a colon and drops a final dot (see
  Wikilinks). The router compares decoded paths, so every encoding of a slug (`'` or `%27`,
  `!` or `%21`, a literal `:`) is served; only the canonical tag, `og:url`, the sitemap,
  redirects and wikilinks name the one encoded form, as on Wikipedia.
- **Indexed pages** are the committed files with a `Gollum::Markup.extensions` extension
  that are not sub-pages (`_Sidebar`, `_Footer`, `_Header`, matched by prefix as
  `Gollum::Page.valid_page_name?` does) and have no segment starting with `.`: the set
  `Gollum::Wiki#pages` returns, less dot-folders. `valid_page_name?` compiles a regular
  expression per call, so `partition_paths` builds one pattern per index build instead.
- **Fallback pages** keep their escaped file URL and are never redirected: an invalid
  title (`:invalid_title`: an empty segment, a segment starting with `.`, a character
  MediaWiki forbids, `# < > [ ] | { }` or a control character, or a `%` escape), a reserved
  first segment ignoring case (`gollum`, `uploads`), a whole collision group (slugs equal
  ignoring case, so no page can shadow another through a case redirect), or a slug equal
  to the path of any file, a page or not, ignoring case (`LICENSE`; `Notes.txt` beside
  `Notes.txt.md`). `check_urls.rb` exits 1 on any.
- **Router rules**, after unescaping, squeezing `/` and stripping a trailing `/`:
  passthrough paths (`/gollum/`, `/uploads/`, dot-segments, robots, sitemap) pass; `/`
  rewrites to `Home.md`; `?raw` rewrites an exact slug and passes everything else; an
  exact slug (case-sensitive, any encoding) rewrites; a path the legacy lookup finds for a
  page with a slug redirects to its canonical path: the file path with or without
  extension, the space form, other letter case, doubled underscores, a trailing slash;
  everything else passes (version URLs `/<file>.md/<sha>`, fallback pages, sub-pages,
  404s, a double-encoded path such as `/Wizard%2527s_Tower`). A redirect always targets a
  canonical path, which decodes to an exact slug and rewrites, so there are no chains or
  loops. The 301 has a path `Location` and `max-age=86400`.
- **Gollum's own lookup** (`Gollum::File.find` with `case_insensitive_tag_lookup`) matches
  the file name case-insensitively and folders case-sensitively; the legacy lookup here
  tries the page path and the path without extension exactly (a full path wins), then the
  only page whose path, path without extension or slug matches with letter case ignored
  and spaces and underscores folded (`fold`: spaces to `_`, runs squeezed, lowercased).
  Sinatra ignores one trailing slash.
- **Middleware order**: `GnollHackFrontDoorOrigin` (ID check, host pinning; section 11) ->
  `GnollHackCrawlerSupport` (HEAD to GET, robots, sitemap) -> `GnollHackAssetCaching` ->
  `GnollHackCleanUrls` -> Gollum. Each `Precious::App.use` in `config.rb` adds the next
  inner layer, so the order is the order of the sections. The rewrite replaces
  `PATH_INFO` with the escaped real path, which Gollum serves as before, `?raw` included.
- **`escaped_url_path` is not overridden**: Gollum's tool pages build history, compare,
  edit and raw URLs from it, and its raw route needs the real file name. Tool pages
  therefore link to `.md` URLs, one 301 per click; they are disallowed in `robots.txt`.
- **Wikilinks**: `generate_link` is overridden (prepended to `Gollum::Filter::Tags`, kept
  private) for `kind == :page_present` only, calling `super` with `url_for` (the encoded
  URL, computed once per index build), so Gollum still handles `base_path`, anchors and CSS
  classes; Home's empty URL renders `href="/"`. The `name` argument is always set for
  present pages, so the link text is unchanged. `Tags#generate_link` passes the joined path
  through `Gollum::Helpers#trim_leading_slashes` (`gsub('%2F', '/')`, then
  `Pathname.new(url).cleanpath`); `Tags#process` also replaces `%2f`. On Windows,
  `cleanpath` follows file name rules for the last segment: `/Foo:_Bar/Baz` becomes
  `/Foo/Baz` and `/a/Vol.` becomes `/a/Vol`, while `%3A`, `%2E`, a dot inside a name and
  `( ) , ! ; @ $ * ~` come through unchanged; so do `%27` and a literal `'` (nothing encodes
  it for us). A literal non-ASCII character would be percent-encoded by libxml2. IIS in
  production answers `%2B` itself with 404 (request filtering rejects double escaping), so
  a page with `+` in its file name is unreachable at any URL.
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
  verification 6 to 22 ms, an index rebuild 25 to 75 ms, a 301 0.55 ms. Gollum renders a
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

## 11. Azure Front Door

The wiki is served through Azure Front Door (Standard/Premium); the profile, DNS and IIS
are configured by hand, and the README's "Azure Front Door" section has the configuration.
Documented Front Door behavior this repository relies on (`front-door-caching`,
`front-door-rules-engine-actions`, `standard-premium/how-to-compression`,
`front-door-http-headers-protocol`):

- A caching route caches a response with no `Cache-Control` for a random one to three
  days. `private`, `no-cache` and `no-store` are not cached, even when a rule set
  overrides the route's caching. `s-maxage`, then `max-age`, then `Expires` set the edge
  lifetime, up to 366 days.
- Revalidation uses `Last-Modified` (`If-Modified-Since`); ETags are not supported.
- Query string behavior is per route. With "Ignore query string" the theme stylesheet's
  `?v=` would be ignored and its `immutable` response pinned under every new hash, so the
  static route uses "Use query string".
- Compression is only on a caching route, for 1 KB to 8 MB, and not for chunked origin
  responses.
- Front Door sends `X-Forwarded-Host` (the client's host), `X-Forwarded-Proto`,
  `X-Forwarded-For`, `X-Azure-ClientIP` and `X-Azure-FDID` (the profile's ID). It connects
  with the origin host name as `Host`.
- A purge ignores query strings and letter case, and takes up to 10 minutes.

How the repository uses it:

- **Two routes**: `wiki-static` (caching on) for `/.gollum/*`, `/gollum/assets/*`,
  `/uploads/*` and `/favicon.ico`, and `wiki-pages` (caching off) for `/*`. Pages stay
  uncached even if a header is ever missing; static lifetimes come from section 7.
- **ID check** (`GnollHackFrontDoorOrigin`, `lib/gnollhack_front_door.rb`): with
  `GNOLLHACK_FRONT_DOOR_ID` set at startup, a request whose `X-Azure-FDID` is not one of
  the IDs (comma-separated, compared lowercased) answers 403 `no-store`, before
  robots and sitemap. Unset, it is off. The IDs are never logged; the startup line gives
  their count.
- **Host pinning**: a request with an `X-Azure-FDID` header gets `HTTP_HOST`,
  `HTTP_X_FORWARDED_HOST` and `SERVER_NAME` set to `SITE_URL`'s host, `https` on port 443,
  and `Forwarded` and `X-Forwarded-Port` removed. Gollum's `/gollum/feed/` builds its links
  from `rack.url_scheme` and `HTTP_HOST`, and Sinatra's `absolute_redirects` (on in
  Sinatra 4.1.1) builds `Location` from Rack's host, which honors `X-Forwarded-Host`, a
  header a direct request can set to anything. Pinning is keyed on the header's presence,
  not its value: pinning to the canonical site is harmless whoever asks, and it works
  before the ID check is on. Local requests and the tools send no such header.
- **WEBrick rewrites `Location`**: `WEBrick::HTTPResponse#setup_header` merges a path
  `Location` (the router's 301) onto its own request URI, which it builds from `Host` and
  `X-Forwarded-Host` outside the application, so pinning the env does not reach it. On a
  Front Door request `GnollHackFrontDoorOrigin` therefore makes a path `Location` absolute
  against `SITE_URL` itself (`GnollHackFrontDoor.public_location`).
- The origin host name appears nowhere in the code.

## 12. Known Limits

- `word_cut` drops a complete last word.
- The ingress search looks at nested block quotes too.
- Non-Markdown formats get the site-wide text.
