---
name: description_verification
description: How to test a change to the SEO meta descriptions or page titles that config.rb gives GnollHack wiki pages. Covers rendering every wiki page through the real Gollum app with the wiki's own layout template, why the gollum --template-dir flag is ignored with --config, a cached fast loop for iterating on the description rules, the checks to run over the output (length, fallbacks, duplicates, legal text, dangling pronouns, lowercased names), diffing against a baseline, the server smoke test, and the CRLF byte check. Read before changing the SEO section of config.rb or reviewing its output.
---

# Verifying Meta Descriptions and Page Titles

`config.rb` adds `{{page_title}}` and `{{description}}` for the wiki's
`.gollum/templates/layout.mustache` (section "SEO: page titles and meta descriptions",
`Precious::Views::Page#description`). The rules are heuristics over rendered HTML, so a
change to one rule can alter hundreds of pages. Verify every change against **all** pages,
never only the page you had in mind.

The wiki content is the `hyvanmielenpelit/GnollHackWiki` repository. The commands below
assume it is checked out at `C:\hmp\GnollHackWiki`; adjust the path if it is elsewhere.
Nothing in this procedure edits the wiki.

## 1. Where the Scripts Go

Write every script and output file below into the **session scratchpad**, never into this
repository or the wiki repository. Pass the paths as arguments.

## 2. The Full Harness: Real Gollum, Real Template

This renders each page through `Precious::App` in-process, with `config.rb` loaded the way
the server loads it, and extracts the description and title from the real HTML. It is the
authoritative check. A full run over about 2,500 pages takes 4-5 minutes; run it in the
background.

```ruby
# Usage: ruby dump_descriptions.rb <config.rb> <wiki> <out.tsv> [page.md ...]
require 'erb'
require 'cgi'
require 'rack/mock'
require 'gollum/app'

config, wiki, out, *only = ARGV
Precious::App.set(:environment, :production)
Precious::App.set(:gollum_path, wiki)
Precious::App.set(:wiki_options, {})
load config
Precious::App.set(:wiki_options, Precious::App.settings.wiki_options.merge(template_dir: File.join(wiki, '.gollum/templates')))

pages = only.empty? ? Dir.glob('**/*.md', base: wiki).reject { |p| p.start_with?('uploads/') }.sort : only
req = Rack::MockRequest.new(Precious::App)
File.open(out, 'w:UTF-8') do |f|
  pages.each do |p|
    url = '/' + p.sub(/\.md\z/, '').split('/').map { |s| ERB::Util.url_encode(s) }.join('/')
    res = req.get(url)
    body = res.body.to_s.dup.force_encoding('UTF-8')
    desc = body[/<meta name="description" content="([^"]*)"/, 1]
    title = body[/<title>([^<]*)<\/title>/, 1]
    f.puts [p, res.status, desc ? CGI.unescapeHTML(desc) : '(none)', title ? CGI.unescapeHTML(title) : ''].join("\t")
  end
end
puts "done #{pages.length}"
```

Output: one row per page, `path <TAB> status <TAB> description <TAB> title`.

> [!IMPORTANT]
> **`gollum --template-dir` is ignored when `--config config.rb` is passed**, because
> `config.rb` replaces the CLI `wiki_options` wholesale. The harness therefore merges
> `template_dir` itself. Without it the pages render with Gollum's built-in layout, which
> has no `{{description}}`, and every row says `(none)`.

Run it once with the config **before** your change (copy the committed `config.rb` to
the scratchpad first) to get `baseline.tsv`, and once after to get `after.tsv`.

## 3. The Fast Loop for Iterating

Rendering Markdown is what makes the harness slow; the description rules themselves take
about three seconds for every page. While iterating, cache each page's rendered HTML once
and call the view directly:

```ruby
# Usage: ruby build_cache.rb <wiki> <out.marshal>
require 'gollum-lib'
wiki_path, out = ARGV
wiki = Gollum::Wiki.new(wiki_path, h1_title: true, case_insensitive_tag_lookup: true, math: :katex)
pages = Dir.glob('**/*.md', base: wiki_path).reject { |p| p.start_with?('uploads/') }.sort
data = pages.map do |p|
  page = wiki.page(p.sub(/\.md\z/, ''))
  next [p, nil, nil, nil] unless page
  [p, page.url_path, page.url_path_title, page.formatted_data]
end
File.binwrite(out, Marshal.dump(data))
puts "cached #{data.length}, missing #{data.count { |d| d[1].nil? }}"
```

```ruby
# Usage: ruby fast_desc.rb <config.rb> <cache.marshal> <out.tsv> [path-regex]
require 'gollum/app'
config, cache, out, filter = ARGV
Precious::App.set(:wiki_options, {})
load config
StubPage = Struct.new(:url_path, :url_path_title, :format)
data = Marshal.load(File.binread(cache))
data = data.select { |d| d[0].match?(Regexp.new(filter)) } if filter
File.open(out, 'w:UTF-8') do |f|
  data.each do |p, url_path, url_title, html|
    v = Precious::Views::Page.allocate
    v.instance_variable_set(:@page, StubPage.new(url_path, url_title, :markdown))
    v.instance_variable_set(:@content, html.to_s.dup.force_encoding('UTF-8'))
    v.instance_variable_set(:@h1_title, true)
    d = begin
      v.description
    rescue => e
      "ERROR #{e.class}: #{e.message} #{e.backtrace.first}"
    end
    f.puts [p, 200, d, v.title].join("\t")
  end
end
puts "done #{data.length}"
```

The wiki options in `build_cache.rb` must match the ones `config.rb` sets that affect
rendering (`h1_title`, `case_insensitive_tag_lookup`, `math`). Rebuild the cache when the
wiki content changes. The fast loop is a stand-in: **always finish with the full harness**,
and check that its rows equal the fast loop's (`diff <(cut -f1,3 a.tsv) <(cut -f1,3 b.tsv)`).

Between iterations, keep the previous output and diff it, so every effect of a rule change
is visible, not only the one you aimed for:

```bash
join -t$'\t' <(cut -f1,3 prev.tsv | sort) <(cut -f1,3 after.tsv | sort) | awk -F'\t' '$2!=$3 {print $1 "\n   OLD " $2 "\n   NEW " $3}'
```

## 4. Checks Over the Output (Git Bash)

> [!IMPORTANT]
> **Set `export LC_ALL=C.UTF-8` first.** Without it Git Bash's `awk` counts bytes, so
> every description ending in "…" (three bytes) looks over the limit, and `grep -P`
> refuses to run.

```bash
export LC_ALL=C.UTF-8
awk -F'\t' 'length($3)>160' after.tsv                                     # over the length limit
awk -F'\t' '$2!=200' after.tsv                                            # failed renders
grep -c ERROR after.tsv                                                   # fast loop exceptions
awk -F'\t' '$3 ~ /^The official GnollHack wiki/ {print $1}' after.tsv     # pages on the site-wide text
cut -f3 after.tsv | grep -v '^The official' | sort | uniq -c | awk '$1>1' | sort -rn   # duplicates
grep -P '\t[^\t]*(trademark|copiable prompt|\tNote that|\t(It|They|These|When you click it)\b)' after.tsv
grep -P '\t[^\t]*(:|\b(of|the|and|to|with|vs\.?)…)\t' after.tsv          # colon or function-word endings
grep -P '\t[^\t]*GnollHack[^\t]* in GnollHack:' after.tsv                 # doubled "in GnollHack"
grep -P '\t[^\t]*\b(google|appImage|europe|barbarian|android device|mac computer)' after.tsv
awk -F'\t' '$1=="Home.md"' after.tsv                                      # must be the site-wide text
```

Read every page the fallback list names, and justify every duplicate group (near-identical
source pages share a description legitimately). "These instructions" and "These guides"
rows from the pronoun grep are self-references the rules allow on purpose.

Then read the descriptions themselves, not only the check output. Page types to sample:
entry pages in each of `Items/`, `Monsters/`, `Spells/`, `Artifacts/`, `Skills/` and
`Conducts/`; index and group pages; `Development/` how-to pages that open with steps;
legal and policy pages; pages that open with a block quote.

## 5. Smoke Test the Server

From PowerShell, in this repository's root:

```powershell
Set-Location C:\hmp\GnollHackWikiConfig; gollum --config config.rb --port 4611 --host 127.0.0.1 C:\hmp\GnollHackWiki
```

> [!IMPORTANT]
> **Pass `--config` as a path relative to the current directory.** On Windows, Gollum 6
> prefixes the working directory to the value, so an absolute path such as
> `C:\hmp\GnollHackWikiConfig\config.rb` fails with a `LoadError` naming a doubled path.
> Git Bash also rewrites `C:/...` arguments, so start the server from PowerShell.

Pick a port nothing else listens on (`netstat -ano | Select-String ':<port>'`): an older
Gollum on the same port answers the requests and makes a failed start look like a pass.
Run the server in the background; startup takes a minute or two. Check that `/` redirects
(302) to `/Home`, and that `/Home`, `/Download`, `/robots.txt`, `/sitemap.xml` and a `HEAD`
request return 200 (`curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:4611/robots.txt`).
Then stop the server, and confirm with `Get-CimInstance Win32_Process -Filter "Name='ruby.exe'"`
that no server of yours is left running.

This server uses Gollum's built-in layout, not the wiki's template (see section 2), so its
pages have no meta description; the harness is what checks the descriptions.

## 6. File Hygiene

- `ruby -c config.rb` reports "Syntax OK".
- `config.rb` and `README.md` are CRLF in the working tree. Verify by byte count, never with
  `grep` or `file`:

  ```powershell
  $b = [IO.File]::ReadAllBytes('C:\hmp\GnollHackWikiConfig\config.rb'); "CR=$(($b | ? { $_ -eq 13 }).Count) LF=$(($b | ? { $_ -eq 10 }).Count)"
  ```

  The two counts must be equal, and the file must not start with a BOM.
- Wiki source typos found while reviewing are reported to the user as a separate follow-up
  for the GnollHackWiki repository. `config.rb` does not paper over them.
