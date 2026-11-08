# GnollHack Wiki Config

This repository contains the [Gollum](https://github.com/gollum/gollum) configuration file for the [GnollHack wiki](https://wiki.gnollhack.com/).

The wiki content itself lives in its own repository, [GnollHackWiki](https://github.com/hyvanmielenpelit/GnollHackWiki).

## Contents

[`config.rb`](config.rb) is loaded by Gollum at startup. It:

- **Sets the wiki options**: uses the `rugged` Git adapter, enables uploads, uses the first `<h1>` as the page title, resolves links case-insensitively, renders math with KaTeX, disables editing, and does not follow renames in the History view.
- **Serializes Markdown rendering**: gollum-lib renders each page inside a block-form `Dir.chdir`, so two concurrent renders can fail with "conflicting chdir during another chdir block". A reentrant lock lets one render step run at a time.
- **Supports crawlers**: answers `HEAD` requests as `GET` without a body, and serves `/robots.txt` and `/sitemap.xml`. The sitemap lists every page with the date of its last commit and is rebuilt after each new commit.
- **Adds SEO template variables**: `{{page_title}}` and `{{description}}`, used by `.gollum/templates/layout.mustache` in the wiki repository. The description comes from a page's ingress, entry header, link list, or first paragraph, and is shortened to 160 characters.

## Usage

Gollum 5 or later with the `rugged` adapter (`gollum-rugged_adapter` gem) is required.

Start Gollum on a clone of the wiki repository and pass this file with `--config`:

```bash
gollum --config /path/to/GnollHackWikiConfig/config.rb /path/to/GnollHackWiki
```

The crawler and SEO settings assume the wiki is served at `https://wiki.gnollhack.com`. Change `SITE_URL` in `config.rb` to serve it elsewhere.

## Related Repositories

- [GnollHackWiki](https://github.com/hyvanmielenpelit/GnollHackWiki): the wiki content.
- [GnollHack](https://github.com/hyvanmielenpelit/GnollHack): the game's source code.

## License

This repository is licensed under the [MIT License](LICENSE). The wiki content in the GnollHackWiki repository has its own license.
