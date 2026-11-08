---
name: description_verification
description: How to test a change to the SEO meta descriptions or page titles that config.rb and lib/gnollhack_seo.rb give GnollHack wiki pages. Covers the tools/ scripts that render every wiki page through the real Gollum app with the wiki's own layout template, the scratch clone of the wiki they run on, how config.rb's wiki options merge with Gollum's command-line options, a cached fast loop that reports which rule chose each description, the unit tests, the checks to run over the output (length, fallbacks, duplicates, front matter overrides, legal text, dangling pronouns, lowercased names), diffing against a baseline, the production-style server smoke test with --template-dir, and the CRLF byte check. Read before changing the SEO rules, the SEO section of config.rb, or a page's description override, or reviewing their output.
---

# Verifying Meta Descriptions and Page Titles

`config.rb` adds `{{page_title}}` and `{{description}}` for the wiki's
`.gollum/templates/layout.mustache` (section "SEO: page titles and meta descriptions",
`Precious::Views::Page#description`). The rules live in `lib/gnollhack_seo.rb`; `config.rb`
is the glue that connects them to Gollum's views. The rules are heuristics over rendered
HTML, so a change to one rule can alter hundreds of pages. Verify every change against
**all** pages, never only the page you had in mind.

The wiki content is the `hyvanmielenpelit/GnollHackWiki` repository. The commands below
assume it is checked out at `C:\hmp\GnollHackWiki`; adjust the path if it is elsewhere.
Nothing in this procedure edits the wiki.

## 1. Where the Scripts and Output Go

The scripts are in this repository's `tools/` folder. Write every output file, and any
one-off script, into the **session scratchpad** (`<scratch>` below), never into this
repository or the wiki repository. Pass the paths as arguments.

Run everything against a **scratch clone** of the wiki, never the working wiki:

```powershell
git clone C:\hmp\GnollHackWiki <scratch>\wiki
```

Gollum reads pages from the **committed content of the served ref**, not from the working
tree, so a page edit is invisible to the scripts and the server until it is committed. To
test uncommitted wiki changes (a page's `description:` override, a template or theme
change), copy them into the clone and commit them there:

```powershell
$src = 'C:\hmp\GnollHackWiki'; $clone = '<scratch>\wiki'
foreach ($line in (& git -C $src -c core.quotepath=false status --porcelain --untracked-files=all)) {
    $rel = $line.Substring(3).Trim('"')
    if ($rel -match ' -> ') { $rel = ($rel -split ' -> ')[-1] }
    $from = Join-Path $src ($rel -replace '/', '\')
    if (-not (Test-Path -LiteralPath $from)) { continue }
    $to = Join-Path $clone ($rel -replace '/', '\')
    New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null
    Copy-Item -LiteralPath $from -Destination $to -Force
}
git -C $clone add -A; git -C $clone commit -q -m "Wiki changes under test"
```

Deleted files are not mirrored. Repeat the copy and commit after every further wiki edit.

## 2. The Full Harness: Real Gollum, Real Template

`tools/dump_descriptions.rb` renders each page through `Precious::App` in-process, with
`config.rb` loaded the way the server loads it, and extracts the description and title from
the real HTML. It is the authoritative check. A full run over about 2,500 pages takes 4-5
minutes; run it in the background.

```powershell
Set-Location C:\hmp\GnollHackWikiConfig
ruby tools/dump_descriptions.rb C:\hmp\GnollHackWikiConfig\config.rb <scratch>\wiki <scratch>\after.tsv [page.md ...]
```

Output: one row per page, `path <TAB> status <TAB> description <TAB> title`, and beside it
`<scratch>\after_sitemap.xml`, the body of `GET /sitemap.xml`. Name pages after the TSV path
to render only those.

> [!IMPORTANT]
> **`config.rb`'s wiki options are merged with the command-line options, not swapped for
> them.** `Precious::App.set(:wiki_options, hash)` merges, because Sinatra's `set` installs a
> merging setter for Hash settings. CLI flags such as `--template-dir` therefore survive, and
> `config.rb`'s keys win where both set one. The harness sets no CLI options, so it merges
> `template_dir` itself. Without it the pages render with Gollum's built-in layout, which has
> no `{{description}}`, and every row says `(none)`.

Run it once with the config **before** your change to get `baseline.tsv`, and once after to
get `after.tsv`. `config.rb` loads `lib/` with `require_relative`, so the baseline needs the
committed `lib/` beside the committed `config.rb`:

```powershell
git -C C:\hmp\GnollHackWikiConfig archive --format=zip -o <scratch>\baseline.zip HEAD
Expand-Archive <scratch>\baseline.zip <scratch>\baseline
ruby tools/dump_descriptions.rb <scratch>\baseline\config.rb <scratch>\wiki <scratch>\baseline.tsv
```

## 3. The Fast Loop for Iterating

Rendering Markdown is what makes the harness slow; the description rules themselves take
about three seconds for every page. While iterating, cache each page's rendered HTML and
front matter once, and call the view directly:

```powershell
ruby tools/build_cache.rb <scratch>\wiki <scratch>\cache.marshal
ruby tools/fast_desc.rb C:\hmp\GnollHackWikiConfig\config.rb <scratch>\cache.marshal <scratch>\fast.tsv [path-regex]
```

`fast_desc.rb` writes `path <TAB> 200 <TAB> description <TAB> title <TAB> source`. The fifth
column, `source`, is the rule that chose the description, read from the view's
`@seo_describer`: `metadata`, `special`, `ingress`, `caution`, `entry`, `link_list`,
`prose`, `list` or `default` (in that order of precedence; see `GnollHackSeo::Describer`).

The wiki options in `build_cache.rb` must match the ones `config.rb` sets that affect
rendering (`h1_title`, `case_insensitive_tag_lookup`, `math`). Rebuild the cache when the
wiki content changes; like Gollum, it reads the clone's committed content. The fast loop is
a stand-in: **always finish with the full harness**, and check that its rows equal the fast
loop's (`diff <(cut -f1,3 a.tsv) <(cut -f1,3 b.tsv)`).

Between iterations, keep the previous output and diff it, so every effect of a rule change
is visible, not only the one you aimed for:

```bash
join -t$'\t' <(cut -f1,3 prev.tsv | sort) <(cut -f1,3 after.tsv | sort) | awk -F'\t' '$2!=$3 {print $1 "\n   OLD " $2 "\n   NEW " $3}'
```

## 4. Checks Over the Output (Git Bash)

Run the unit tests first, from this repository's root. Both must report 0 failures and
0 errors:

```powershell
ruby -Ilib test\test_gnollhack_seo.rb
ruby -Ilib test\test_gnollhack_assets.rb
```

> [!IMPORTANT]
> **Set `export LC_ALL=C.UTF-8` first.** Without it Git Bash's `awk` counts bytes, so
> every description ending in "…" (three bytes) looks over the limit, and `grep -P`
> refuses to run.

```bash
export LC_ALL=C.UTF-8
awk -F'\t' 'length($3)>160' after.tsv                                     # over the length limit
awk -F'\t' '$2!=200' after.tsv                                            # failed renders
grep -c ERROR fast.tsv                                                    # fast loop exceptions
cut -f5 fast.tsv | sort | uniq -c | sort -rn                              # pages per rule
awk -F'\t' '$5=="default" {print $1}' fast.tsv                            # pages on the site-wide text by fallback
awk -F'\t' '$5=="special" {print $1}' fast.tsv                            # Home, _Sidebar and the like
awk -F'\t' '$3 ~ /^The official GnollHack wiki/ {print $1}' after.tsv     # pages on the site-wide text
cut -f3 after.tsv | grep -v '^The official' | sort | uniq -c | awk '$1>1' | sort -rn   # duplicates
grep -P '\t[^\t]*(trademark|copiable prompt|\tNote that|\t(It|They|These|When you click it)\b)' after.tsv
grep -P '\t[^\t]*(:|\b(of|the|and|to|with|vs\.?)…)\t' after.tsv          # colon or function-word endings
grep -P '\t[^\t]*GnollHack[^\t]* in GnollHack:' after.tsv                 # doubled "in GnollHack"
grep -P '\t[^\t]*\b(google|appImage|europe|barbarian|android device|mac computer)' after.tsv
awk -F'\t' '$1=="Home.md"' after.tsv                                      # must be the site-wide text
```

Compare the per-rule counts with the baseline's; a shift between rules is where a rule
change shows first.

**Front matter overrides.** A page with a `description:` front matter has exactly that
text, after entity decoding, as its row, its source is `metadata`, and the override is at
most 160 characters. With `CLONE` set to the scratch clone (`C:/.../wiki`):

```bash
ruby -ryaml -rcgi -e '
rows = File.readlines(ARGV[1], chomp: true, encoding: "UTF-8").to_h { |l| c = l.split("\t", -1); [c[0], c] }
Dir.glob("**/*.md", base: ARGV[0]).each do |p|
  fm = File.read(File.join(ARGV[0], p), encoding: "UTF-8")[/\A---\r?\n(.*?)\r?\n---\r?$/m, 1]
  next unless fm
  meta = begin
    YAML.safe_load(fm.delete("\r"))
  rescue Psych::Exception => e
    puts "#{p}: YAML error #{e.message}"
    next
  end
  want = meta.is_a?(Hash) ? meta["description"] : nil
  next unless want.is_a?(String)
  want = CGI.unescapeHTML(want).strip
  row = rows[p]
  if row.nil? then puts "#{p}: no row"; next end
  puts "#{p}: #{want.length} characters" if want.length > 160
  puts "#{p}: row differs: #{row[2]}" unless row[2] == want
  puts "#{p}: source #{row[4]}" if row[4] && row[4] != "metadata"
end
puts "checked"' "$CLONE" fast.tsv
```

Run it on `after.tsv` too (it has no source column, so only the text is compared). Any line
before `checked` is a failure.

**Rendered pages.** An override page shows no metadata `<table` before its first heading,
and Home has the site-wide text both on `/Home` and on a version URL, `/Home/<sha>`.
`MSYS_NO_PATHCONV=1` stops Git Bash from rewriting the `/Download` arguments into Windows
paths:

```bash
MSYS_NO_PATHCONV=1 ruby -rrack/mock -rgollum/app -rcgi -e '
config, wiki, *urls = ARGV
Precious::App.set(:environment, :production)
Precious::App.set(:gollum_path, wiki)
Precious::App.set(:wiki_options, {})
load config
Precious::App.set(:wiki_options, Precious::App.settings.wiki_options.merge(template_dir: File.join(wiki, ".gollum/templates")))
req = Rack::MockRequest.new(Precious::App)
urls.each do |url|
  res = req.get(url)
  body = res.body.to_s.dup.force_encoding("UTF-8")
  desc = CGI.unescapeHTML(body[/<meta name="description" content="([^"]*)"/, 1].to_s)
  lead = body[/<div class="markdown-body .*?(?=<h[1-6][\s>]|\z)/m].to_s
  puts [url, res.status, lead.include?("<table") ? "TABLE" : "no table", desc].join("\t")
end' C:/hmp/GnollHackWikiConfig/config.rb "$CLONE" /Download /Home "/Home/$(git -C "$CLONE" rev-parse HEAD)"
```

Add every other override page to the URL list (URL-encoded, without `.md`). Every row must
say `200` and `no table`; `/Download` shows its override, and both Home rows show the
site-wide text.

Read every page the fallback list names, and justify every duplicate group (near-identical
source pages share a description legitimately). "These instructions" and "These guides"
rows from the pronoun grep are self-references the rules allow on purpose.

Then read the descriptions themselves, not only the check output. Page types to sample:
entry pages in each of `Items/`, `Monsters/`, `Spells/`, `Artifacts/`, `Skills/` and
`Conducts/`; index and group pages; `Development/` how-to pages that open with steps;
legal and policy pages; pages that open with a block quote.

## 5. Smoke Test the Server

Run a production-style server on the scratch clone, with the wiki's template directory.
Gollum serves a theme file (`/.gollum/css/…`, `/.gollum/fonts/…`, `/.gollum/images/…`) only
if it exists in the committed tree of the served ref; an untracked file answers 404. Once
found there, its bytes come from the working tree on disk. So copy the theme files and
template into the clone and commit them there first (section 1). From PowerShell:

```powershell
Set-Location C:\hmp\GnollHackWikiConfig; gollum --config config.rb <scratch>\wiki --template-dir <scratch>\wiki\.gollum\templates\ --port 4611 --host 127.0.0.1
```

Pass the wiki path and `--template-dir` as absolute paths, as production does.

> [!IMPORTANT]
> **Pass `--config` as a path relative to the current directory.** On Windows, Gollum 6
> prefixes the working directory to the value, so an absolute path such as
> `C:\hmp\GnollHackWikiConfig\config.rb` fails with a `LoadError` naming a doubled path.
> Git Bash also rewrites `C:/...` arguments, so start the server from PowerShell.

Pick a port nothing else listens on (`netstat -ano | Select-String ':<port>'`): an older
Gollum on the same port answers the requests and makes a failed start look like a pass.
Run the server in the background; startup takes a minute or two. Then, from Git Bash:

```bash
u=http://127.0.0.1:4611
code() { curl -s -o /dev/null -w "%{http_code} $*\n" "$@"; }
code "$u/"                                   # 302, Location ends in /Home
code "$u/Home"; code "$u/Download"; code "$u/robots.txt"; code "$u/sitemap.xml"
code "$u/.gollum/css/gnollhack-theme.css"; code "$u/.gollum/fonts/cinzel-latin-wght-normal.woff2"
code -I "$u/Home"                            # HEAD request
curl -s "$u/Download" | grep -o '<meta name="description" content="[^"]*"'   # the override
curl -s "$u/Home" | grep -oE 'gnollhack-theme\.css\?v=[0-9a-f]{16}'          # versioned stylesheet
curl -s "$u/Home" | grep -c 'gollum.mermaid'                                 # 0
curl -s "$u/sitemap.xml" | grep -o '<loc>[^<]*</loc>' | head -n 3
curl -s "$u/sitemap.xml" | grep -cE '<loc>https://wiki\.gnollhack\.com/</loc>|README\.md'   # 0
```

All codes are 200 except the 302 of `/`. The sitemap's first `<loc>` is
`https://wiki.gnollhack.com/Home.md`, with no `/` entry and no `README.md`. A stylesheet URL
with the current `?v=` answers `cache-control: public, max-age=31536000, immutable`
(`curl -sI "$u/.gollum/css/gnollhack-theme.css?v=<hex>"`).

Then stop the server, and confirm with `Get-CimInstance Win32_Process -Filter "Name='ruby.exe'"`
that no server of yours is left running.

## 6. File Hygiene

- `config.rb`, `README.md`, and every `.rb` file in `lib/`, `test/` and `tools/` are CRLF in
  the working tree with no BOM, and every `.rb` file passes `ruby -c` ("Syntax OK"). Verify
  line endings by byte count, never with `grep` or `file`:

  ```powershell
  Set-Location C:\hmp\GnollHackWikiConfig
  $files = @('config.rb', 'README.md') + (Get-ChildItem lib, test, tools -Filter *.rb | ForEach-Object { Resolve-Path -Relative $_.FullName })
  foreach ($f in $files) {
      $b = [IO.File]::ReadAllBytes((Resolve-Path $f))
      $bom = $b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF
      "$f CR=$(($b | ? { $_ -eq 13 }).Count) LF=$(($b | ? { $_ -eq 10 }).Count) BOM=$bom"
  }
  foreach ($f in ($files | Where-Object { $_ -like '*.rb' })) { ruby -c $f }
  ```

  For each file the two counts must be equal and `BOM` must be `False`.
- Wiki source typos found while reviewing are reported to the user as a separate follow-up
  for the GnollHackWiki repository. `config.rb` does not paper over them.
