---
name: description-verification
description: How to test a change to the SEO meta descriptions or page titles that config.rb and lib/gnollhack_seo.rb give GnollHack wiki pages. Covers the tools/ scripts that render every wiki page through the real Gollum app with the wiki's own layout template, the scratch clone of the wiki they run on, how config.rb's wiki options merge with Gollum's command-line options, a cached fast loop that reports which rule chose each description, the unit tests, the checks to run over the output (length, fallbacks, duplicates, front matter overrides, legal text, dangling pronouns, lowercased names), diffing against a baseline, the production-style server smoke test with --template-dir, and the CRLF byte check. Read before changing the SEO rules, the SEO section of config.rb, or a page's description override, or reviewing their output.
---

The full skill lives in this repository's tool-neutral agent directory (`.agents/`),
which is shared with other AI coding agents. This file is only a pointer.

Read `.agents/skills/description_verification/SKILL.md` (path relative to the repository root) in full
before proceeding, and follow it. Any `references/` files it links are relative to that
same directory.
