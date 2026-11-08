---
name: gollum-config-internals
description: "Gollum and Sinatra behavior that config.rb, lib/gnollhack_seo.rb and lib/gnollhack_assets.rb depend on: how the config is loaded and merged, how page front matter is parsed, sanitized and shown, what Gollum serves from disk versus the committed ref, view and title quirks, the render lock, the sitemap, and the asset cache policy. Read before changing config.rb, adding a page metadata key, or changing how wiki assets are cached."
---

The full skill lives in this repository's tool-neutral agent directory (`.agents/`),
which is shared with other AI coding agents. This file is only a pointer.

Read `.agents/skills/gollum_config_internals/SKILL.md` (path relative to the repository root) in full
before proceeding, and follow it. Any `references/` files it links are relative to that
same directory.
