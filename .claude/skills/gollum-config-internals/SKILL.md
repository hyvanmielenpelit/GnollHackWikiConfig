---
name: gollum-config-internals
description: "Gollum and Sinatra behavior that config.rb and the libraries in lib/ depend on: how the config is loaded and merged, how page front matter is parsed, sanitized and shown, what Gollum serves from disk versus the committed ref, view and title quirks, the render lock, the sitemap, the asset cache policy, URL routing (slugs, the page index, rewrites and 301s, wikilinks, the commit check), and the rendered page cache (what is cached, the epoch, what ends an entry). Read before changing config.rb, adding a page metadata key, changing how wiki assets are cached, or changing anything a rendered page depends on."
---

The full skill lives in this repository's tool-neutral agent directory (`.agents/`),
which is shared with other AI coding agents. This file is only a pointer.

Read `.agents/skills/gollum_config_internals/SKILL.md` (path relative to the repository root) in full
before proceeding, and follow it. Any `references/` files it links are relative to that
same directory.
