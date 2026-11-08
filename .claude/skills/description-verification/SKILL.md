---
name: description-verification
description: How to test a change to the SEO meta descriptions or page titles that config.rb gives GnollHack wiki pages. Covers rendering every wiki page through the real Gollum app with the wiki's own layout template, why the gollum --template-dir flag is ignored with --config, a cached fast loop for iterating on the description rules, the checks to run over the output (length, fallbacks, duplicates, legal text, dangling pronouns, lowercased names), diffing against a baseline, the server smoke test, and the CRLF byte check. Read before changing the SEO section of config.rb or reviewing its output.
---

The full skill lives in this repository's tool-neutral agent directory (`.agents/`),
which is shared with other AI coding agents. This file is only a pointer.

Read `.agents/skills/description_verification/SKILL.md` (path relative to the repository root) in full
before proceeding, and follow it. Any `references/` files it links are relative to that
same directory.
