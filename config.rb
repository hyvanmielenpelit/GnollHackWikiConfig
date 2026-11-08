  # Launch Gollum using a specific git adapter. See https://github.com/gollum/gollum/wiki/Git-adapters
  # Default: rugged
  #
  # Equivalent to --adapter [ADAPTER]

  module Gollum
    # to require 'my_adapter':
    Gollum::GIT_ADAPTER = "rugged"
  end

  wiki_options = {

    ##############################################################################
    #-----------------------------------------------------------------------------

    #-----------------------------------------------------------------------------
    # Enable file uploads. If set to 'dir', Gollum will store all uploads in the
    # /uploads/ directory in repository root. If set to 'page', Gollum will
    # store each upload at the currently edited page.
    # Default: false

    # Equivalent to --allow-uploads dir
    
    allow_uploads: true,

    # Equivalent to --allow-uploads page
    #allow_uploads: true,
    #per_page_uploads: true,

    #-----------------------------------------------------------------------------
    # Set the path to look for static assets.
    #
    # Equivalent to --assets [PATH]

    #static_assets_path: "",

    #-----------------------------------------------------------------------------
    # Tell Gollum that the git repository should be treated as bare.
    #
    # Equivalent to --bare

    #repo_is_bare: true,

    #-----------------------------------------------------------------------------
    # Specify the leading portion of all Gollum URLs (path info). Setting this to
    # /wiki will make the wiki accessible under http://localhost:4567/wiki/.
    # Default: /
    #
    # Equivalent to --base-path [PATH]

    #base_path: [PATH],

    #-----------------------------------------------------------------------------
    # Enable support for annotations using CriticMarkup.
    #
    # Equivalent to --critic-markup

    #critic_markup: true,

    #-----------------------------------------------------------------------------
    # Tell Gollum to inject custom CSS into each page. Uses custom.css from wiki
    # root
    #
    # Equivalent to --css

    #css: true,

    #-----------------------------------------------------------------------------
    # What should the default keybinding be on the edit page? Note: the editor will anyway remember the last choice the user made, so this is only to specify the default.

    #default_keybinding: :vim
    #default_keybinding: :emacs

    #-----------------------------------------------------------------------------
    # Parse and interpret emoji tags (e.g. :heart:) except when the leading colon
    # is backslashed (e.g. \:heart:).
    #
    # Equivalent to --emoji

    #emoji: true,

    #-----------------------------------------------------------------------------
    # Tell Gollum to use the first <h1> as page title.
    #
    # Equivalent to --h1-title

    h1_title: true,

    #-----------------------------------------------------------------------------
    # Specify the hostname or IP address to listen on.
    # Default: '0.0.0.0'.
    #
    # Equivalent to --host [HOST]

    # ???

    #-----------------------------------------------------------------------------
    # Launch Gollum in "console mode", with a predefined API.
    #
    # Equivalent to --irb

    # ???

    #-----------------------------------------------------------------------------
    # Tell Gollum to inject custom JS into each page. Uses custom.js from wiki
    # root.
    #
    # Equivalent to --js

    #js: true,

    #-----------------------------------------------------------------------------
    # Compatibility with 4.x
    # https://github.com/gollum/gollum/wiki/5.0-release-notes#compatibility-option
    #
    # Internal links resolve case-insensitively, will treat spaces as hyphens, and
    # will match the first page found with a certain filename, anywhere in the
    # repository. Provides compatibility with Gollum 4.x.
    #
    # Equivalent to --lenient-tag-lookup

    # hyphened_tag_lookup: true,
    case_insensitive_tag_lookup: true,
    # global_tag_lookup: true,

    #-----------------------------------------------------------------------------
    # Use the browser's local timezone instead of the server's timezone for displaying dates.

    #show_local_time: true

    #-----------------------------------------------------------------------------
    # Equivalent to --math. Set math parsing to either mathjax or katex (default)

    #math: :mathjax,
    math: :katex,

    #-----------------------------------------------------------------------------
    # Specify path to a custom MathJax configuration.
    # Default: mathjax.config.js file from repository root.
    #
    # Equivalent to --mathjax-config [FILE]

    #mathjax_config: [FILE],

    #-----------------------------------------------------------------------------
    # Do not render metadata tables in pages.
    #
    # Equivalent to --no-display-metadata

    #display_metadata: false,

    #-----------------------------------------------------------------------------
    # Disable the feature of editing pages.
    # Default: true
    #
    # Equivalent to --no-edit

    allow_editing: false,

    #-----------------------------------------------------------------------------
    # Specify the subdirectory for all pages. If set, Gollum will only serve pages
    # from this directory and its subdirectories.
    # Default: repository root.
    #
    # Equivalent to --page-file-dir [PATH]

    #page_file_dir: [PATH],

    #-----------------------------------------------------------------------------
    # Follow pages across renames in the History view. You may set this to `false` to improve performance on wikis with very large histories. 
    # Default: true.

    follow_renames: false,

    #-----------------------------------------------------------------------------
    # Specify the port to bind Gollum with.
    # Default: 4567.
    #
    # Equivalent to --port [PORT]

    # ???

    #-----------------------------------------------------------------------------
    # Specify the git branch to serve.
    # Default: master.
    #
    # Equivalent to --ref [REF]

    # ref: "files-to-subdirs"

    #-----------------------------------------------------------------------------
    # Use static assets.
    # Defaults to false in development/test, true in
    # production/staging.

    # Equivalent to --static
    #static: true,

    # Equivalent to --no-static
    #static: false,

    #-----------------------------------------------------------------------------
    # Specify custom mustache template directory.
    #
    # Equivalent to --template-dir [PATH]

    #template_dir: ".gollum/templates/"

    #-----------------------------------------------------------------------------
    # Use _Template in root as a template for new pages. Must be committed.
    #
    # Equivalent to --template-page

    #template_page: true,

    #-----------------------------------------------------------------------------
    # Tell Gollum to use specific user icons for history view. Can be set to
    # gravatar, identicon or none.
    # Default: none.
    #
    # Equivalent to --user-icons [MODE]

    #user_icons: [MODE],

    ##############################################################################
    # Metadata (front matter)

    #-----------------------------------------------------------------------------
    # Header counting
    # Default: false
    # Can also be a pre-defined counter. See
    # https://www.w3.org/TR/css-counter-styles-3/#predefined-counters

    #header_enum: false,
    #header_enum: 'decimal-leading-zero',

    #-----------------------------------------------------------------------------
    # Global metadata. Arbitrary metadata that will be applied to each page.

    #metadata: {
    #  monkeyboys: 'are loose in the facility'
    #},

    ##############################################################################
    # Tips

    #-----------------------------------------------------------------------------
    # Force table of contents tag ([[_TOC_]]) into each page.
    # ??? How to set the level in the configuration file?
    # https://github.com/gollum/gollum/wiki#table-of-contents-toc-tag
    # Default: false

    #universal_toc: false,

    #-----------------------------------------------------------------------------
    # Move the sidebar to the left of the page
    # https://github.com/gollum/gollum/issues/1450#issuecomment-599124384

    #sidebar: :left,

    #-----------------------------------------------------------------------------
    # Change the home page name
    # https://github.com/gollum/gollum/issues/1569#issuecomment-633033895

    #index_page: 'index',

    #-----------------------------------------------------------------------------
    # Change the number of changes in the rss feed

    #pagination_count: 15
  }

  #-------------------------------------------------------------------------------
  # Change default markup
  #Precious::App.set(:default_markup, :"github/markdown")

  Precious::App.set(:wiki_options, wiki_options)

  #markdown = Gollum::Markup.formats[:markdown]
  #markdown[:reverse_links] = true
  #Gollum::Markup.formats.delete(:markdown)
  #Gollum::Markup.register(:markdown, markdown[:name])

  ##############################################################################
  # Serialized Markdown rendering
  #
  # gollum-lib renders each page inside a block-form Dir.chdir, which changes
  # the working directory of the whole process. When two requests render at
  # the same time, Ruby raises "conflicting chdir during another chdir block",
  # and gollum-lib serves that message as the page body with status 200. A
  # reentrant lock lets one render step run at a time; the rest of a request
  # still runs in parallel.

  require 'monitor'

  module GnollHackSerializedRender
    LOCK = Monitor.new

    def extract(data)
      LOCK.synchronize { super }
    end
  end

  Gollum::Filter::Render.prepend(GnollHackSerializedRender)

  ##############################################################################
  # Crawler support: HEAD requests, robots.txt, and sitemap.xml
  #
  # - HEAD: Gollum answers every method but GET with 403 when editing is off.
  #   A HEAD request is passed on as a GET and its body dropped, so link
  #   checkers and crawlers get the same status and headers as a GET.
  # - /robots.txt lets every crawler, search engine and AI agent read the wiki.
  #   Only Gollum's own tool pages (history, diffs, search, edit forms) and the
  #   repository's AI instruction folders are left out; Gollum's CSS and
  #   JavaScript stay readable so pages render for crawlers.
  # - /sitemap.xml lists every page with the date of its last commit. It is
  #   built from the served branch on first request and again after each new
  #   commit.

  require 'cgi'
  require 'rugged'

  class GnollHackCrawlerSupport
    SITE_URL = 'https://wiki.gnollhack.com'

    # Repository folders whose files Gollum serves but which are not wiki pages.
    PRIVATE_FOLDERS = %w[.agents .claude].freeze

    # Pages left out of the sitemap: Home.md is listed as the site root, and
    # README.md is the repository's GitHub front page.
    SITEMAP_EXCLUDED = %w[Home.md README.md].freeze
    HOME_PAGE = 'Home.md'

    ROBOTS_TXT = <<~TEXT
      # All crawlers, search engines, and AI agents may read the GnollHack Wiki.
      User-agent: *
      Allow: /
      Allow: /gollum/assets/
      Disallow: /gollum/
      #{PRIVATE_FOLDERS.map { |f| "Disallow: /#{f}/" }.join("\n")}

      Sitemap: #{SITE_URL}/sitemap.xml
    TEXT

    def initialize(app)
      @app = app
      @sitemap_lock = Mutex.new
      @sitemap = nil
      @sitemap_commit = nil
    end

    def call(env)
      head = env['REQUEST_METHOD'] == 'HEAD'
      env = env.merge('REQUEST_METHOD' => 'GET') if head

      status, headers, body =
        if env['REQUEST_METHOD'] == 'GET' && env['PATH_INFO'] == '/robots.txt'
          text_response(ROBOTS_TXT, 'text/plain; charset=utf-8')
        elsif env['REQUEST_METHOD'] == 'GET' && env['PATH_INFO'] == '/sitemap.xml'
          text_response(sitemap, 'application/xml; charset=utf-8')
        else
          @app.call(env)
        end

      if head
        body.close if body.respond_to?(:close)
        body = []
      end
      [status, headers, body]
    end

    private

    def text_response(text, type)
      [200, { 'content-type' => type, 'content-length' => text.bytesize.to_s,
              'cache-control' => 'public, max-age=3600' }, [text]]
    end

    def wiki
      Gollum::Wiki.new(Precious::App.settings.gollum_path, Precious::App.settings.wiki_options)
    end

    def sitemap
      @sitemap_lock.synchronize do
        current = wiki
        commit = Rugged::Repository.new(current.path).rev_parse(current.ref)
        if @sitemap_commit != commit.oid
          @sitemap = build_sitemap(current, commit)
          @sitemap_commit = commit.oid
        end
        @sitemap
      end
    end

    def build_sitemap(current, commit)
      dates = last_commit_dates(Rugged::Repository.new(current.path), commit)
      entries = []
      home = current.pages.find { |p| p.path == HOME_PAGE }
      entries << ["#{SITE_URL}/", home && dates[home.path]]
      current.pages.each do |page|
        next if page.path.split('/').any? { |part| part.start_with?('.') }
        next if SITEMAP_EXCLUDED.include?(page.path)
        entries << ["#{SITE_URL}/#{page.escaped_url_path}", dates[page.path]]
      end

      urls = entries.map do |loc, time|
        lastmod = time ? "<lastmod>#{time.getutc.strftime('%Y-%m-%dT%H:%M:%SZ')}</lastmod>" : ''
        "  <url><loc>#{CGI.escapeHTML(loc)}</loc>#{lastmod}</url>"
      end
      %(<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n#{urls.join("\n")}\n</urlset>\n)
    end

    # The time of the newest commit that changed each path, from one walk of
    # the history.
    def last_commit_dates(repo, commit)
      dates = {}
      walker = Rugged::Walker.new(repo)
      walker.sorting(Rugged::SORT_DATE)
      walker.push(commit.oid)
      walker.each do |c|
        parent = c.parents.first
        diff = parent ? parent.tree.diff(c.tree) : c.tree.diff(nil)
        diff.each_delta do |delta|
          path = delta.new_file[:path].dup.force_encoding('UTF-8')
          dates[path] ||= c.time
        end
      end
      dates
    end
  end

  Precious::App.use GnollHackCrawlerSupport

  ##############################################################################
  # SEO: page titles and meta descriptions
  #
  # Template variables added for layout.mustache:
  #   {{page_title}}  - "<title> – GnollHack Wiki", or just "GnollHack Wiki" on
  #                     the page whose title is already the site name (Home.md
  #                     with its H1 heading).
  #   {{description}} - plain text of at most DESCRIPTION_MAX_LENGTH
  #                     characters, from the first of these that a page has:
  #                     1. on the home page, a page whose title is the site
  #                        name, and pages whose name starts with "_", the
  #                        site-wide text;
  #                     2. its ingress (the first block quote starting with the
  #                        pointing-hand emoji);
  #                     3. a caution or warning block quote that opens the page;
  #                     4. on an entry page in an ENTRY_FOLDERS folder, a summary
  #                        of its title and first heading, its Description
  #                        section or first paragraph, and its header fields;
  #                     5. on a page whose first list or table of links comes
  #                        before any prose, the first link names and the
  #                        number of the others;
  #                     6. its first usable paragraph of prose;
  #                     7. on a page that opens with a list or table, its items;
  #                     8. the site-wide text, which non-page views also get.
  #                     Legal notices, side notes, cross-references, and text
  #                     that depends on its surroundings are not used. A text
  #                     ending in a colon takes the list or table after it.
  #                     Long text is cut at a sentence end, or else at a word.
  #
  # Gollum loads the Page view lazily; it must be loaded here before it is
  # extended, or this file would define a bare Page class in its place.

  require 'set'
  require 'gollum/views/page'

  module Precious
    module Views
      class Layout
        SITE_NAME = 'GnollHack Wiki'
        TITLE_SEPARATOR = " – "
        DEFAULT_DESCRIPTION = 'The official GnollHack wiki: guides, roles, monsters, items, spells, and game mechanics for GnollHack, a free and open-source roguelike based on NetHack.'
        DESCRIPTION_MAX_LENGTH = 160

        def page_title
          base = title.to_s.strip
          return SITE_NAME if base.empty? || base == SITE_NAME
          "#{base}#{TITLE_SEPARATOR}#{SITE_NAME}"
        end

        def description
          DEFAULT_DESCRIPTION
        end
      end

      class Page
        HOME_PAGE = 'Home'
        INGRESS_PREFIX = /\A\u{1F449}\u{FE0F}?\s*/
        CAUTION_PREFIX = /\A(?:\u{1F6D1}|\u{26A0})\u{FE0F}?\s*/
        CAUTION_LABEL = /\A(?:Caution|Warning)\s*:\s*/i
        LEADING_SYMBOLS = /\A[^\p{L}\p{N}]+/
        MIN_PROSE_LENGTH = 40
        MIN_PROSE_WORDS = 4
        LIST_NAMES_SHOWN = 5
        POWERS_SHOWN = 3
        POWERS_JOINED_LENGTH = 90

        # A long text is cut at the last sentence end at or after
        # SENTENCE_CUT_MIN characters, or else at the last clause boundary at
        # or after CLAUSE_CUT_MIN characters.
        SENTENCE_CUT_MIN = 90
        CLAUSE_CUT_MIN = 100

        # Text that does not describe the page it is on: legal small print,
        # cross-references, side notes, and text that points at other text.
        LEGAL_TEXT = /\btrademarks?\b|\bregistered\b.*\bmark\b|©|\bcopyright\b|\ball rights reserved\b|\bagree to be bound\b/i
        CROSS_REFERENCE = /\A(?:the copiable prompt|see|visit|for more information)\b|\bis on the .{1,80} page\.?\z/i
        SIDE_NOTE = /\ANote(?::|\s+that\b)/i
        DANGLING_START = /\A(?:It|They|Them|Those|That|These|This|However|Thus|Therefore|Otherwise|Instead|With these|When you click it|The problem|Please follow these)\b/
        SELF_REFERENCE = /\A(?:This is (?:a|an|the)\b|These are (?:the )?(?:instructions|guidelines|steps)\b|(?:This|These) (?:page|guide|guides|article|document|instructions|wiki|section|list|policy|tutorial|manual|Terms|privacy policy)\b)/
        DANGLING_REFERENCE = /\b(?:the above|described above|above (?:formula|table|list|section|image)|(?:requirements|instructions|steps|examples?) above|(?:see|shown|listed|described|as) below|the (?:table|list) below|this section and the next|to do this|like this)\b/i
        FILLER_SENTENCE = /\A(?:This|It) is (?:mostly |pretty )?(?:self-explanatory|obvious)\.\s*/i
        LEGAL_DEFINITION = /\s*\((?:collectively,\s*)?(?:the\s+)?["“][^"”]+["”]\)/
        BARE_URL = %r{\A\S+://\S+\z}
        AS_FOLLOWS = /,?\s*as follows\s*:\z/i
        THE_FOLLOWING = /\bthe following\b|\bfollowing \p{L}+:?\z/i
        CAUTION_REFERENCE = /\A(?:See\b|For\b.*\bsee\b)/i

        # Sentences of an entry's text that only point to another page.
        ENTRY_REFERENCE = /\A(?:For more information|See (?:the|also)\b)/i

        # Sentence ends, except after common abbreviations, and the clause
        # boundaries a long text may be cut at.
        SENTENCE_BREAK = /(?<=[.!?])(?<!\be\.g\.)(?<!\bi\.e\.)(?<!\bvs\.)\s+(?=["“(\p{Lu}\p{N}])/
        SENTENCE_END = /[.!?…]["”')]*\z/
        CLAUSE_BREAK = /[,;](?=\s)|\s[—–](?=\s)/

        # Words a cut text must not end on.
        TRAILING_WORD = /\s+(?:a|an|the|of|to|in|on|for|with|and|or|are|is|by|at|from|vs\.?|all|both|many|some|any|each|every|its|their|your|our|that|which|who|when|while|than|as|into|upon|around|about|you|can|so|but|if|\d+\s*×|×)\z/i

        # A "Term — definition" or "Term: definition" list item.
        TERM_DEFINITION = /\A[^—:]{1,40}(?:\s[—–-]|:)\s/

        # Sections an item or artifact page lists its powers in, in order of
        # preference, and the routine artifact properties left out of them.
        POWER_SECTIONS = [/mythic powers/i, /conferred powers/i, /artifact properties/i, /item properties/i].freeze
        ARTIFACT_POWER_SECTIONS = [/artifact properties/i, /conferred powers/i, /mythic powers/i, /item properties/i].freeze
        ROUTINE_PROPERTY = /\A(?:Alignment|Artifact|Intelligent|Attack bonus)\b|\AIs (?:weapon|armor) when wielded\b/i
        POWER_CONDITION = / when (?:worn|wielded|carried|eaten|invoked|applied)\z/

        LOWERCASE_FIELDS = %w[Alignment Material].freeze
        MATERIAL_WORDS = { 'wooden' => 'wood' }.freeze
        ZERO_VALUE = /\A[0.]+\s*(?:lbs?|gold)\z/i

        # Folders whose pages open with a "## <kind>" heading and a header list
        # of "- **Field:** value" lines, and the noun each one's pages take
        # when the heading is generic.
        ENTRY_KINDS = {
          'Skills' => 'skill',
          'Conducts' => 'conduct',
          'Spells' => 'spell',
          'Monsters' => 'monster',
          'Items' => 'item',
          'Artifacts' => 'artifact'
        }.freeze
        ENTRY_FOLDERS = ENTRY_KINDS.keys.freeze
        GENERIC_KIND = /\A(?:Overview|Description|General)\z/i

        # Nouns naming a folder's pages, for "<title> <noun> in GnollHack".
        FOLDER_NOUNS = {
          'Conducts' => 'conduct',
          'Difficulties' => 'difficulty level',
          'Dungeon' => 'dungeon level',
          'Races' => 'race',
          'Roles' => 'role',
          'Rooms' => 'room'
        }.freeze

        # Header fields quoted in an entry page's description, in order, with
        # the wording each one takes.
        ENTRY_FACTS = {
          'Monsters' => [['Armor class', 'armor class %s'],
                         ['Magic resistance', 'magic resistance %s'],
                         ['Alignment', 'alignment %s']],
          'Spells' => [['Mana cost', 'mana cost %s'],
                       ['Duration', 'duration %s'],
                       ['Range', 'range %s']],
          'Items' => [['Base damage - Small', 'damage %s vs. small'],
                      ['Base damage - Large', '%s vs. large'],
                      ['Base armor class bonus', 'AC bonus %s'],
                      ['Weight', 'weight %s'],
                      ['Base value', 'base value %s']],
          'Artifacts' => [['Base damage - Small', 'damage %s vs. small'],
                          ['Base damage - Large', '%s vs. large'],
                          ['Material', 'made of %s'],
                          ['Base value', 'base value %s']]
        }.freeze

        def description
          @description ||= begin
            if special_page?
              DEFAULT_DESCRIPTION
            elsif (text = ingress_text || caution_text)
              shorten_description(text)
            elsif (text = entry_summary)
              text
            elsif (text = link_list_summary || first_prose || first_list_summary)
              shorten_description(text)
            else
              super
            end
          end
        end

        private

        # 1. The home page, a page titled with the site name, and pages such
        # as _Sidebar and _Footer.
        def special_page?
          path = @page.url_path.to_s
          path == HOME_PAGE || title.to_s.strip == SITE_NAME || File.basename(path).start_with?('_')
        end

        # The page's rendered content inside a wrapper, parsed as Gollum parses
        # it; a bare fragment can come back wrapped in a stray body element.
        # Line breaks become spaces, so text on both sides stays apart.
        def content_document
          @content_document ||= begin
            root = Nokogiri::HTML.fragment(%{<div id="seo-root">#{@content}</div>}, 'UTF-8').at_css('div#seo-root')
            root.css('br').each { |br| br.add_next_sibling(Nokogiri::XML::Text.new(' ', root.document)) }
            root
          end
        end

        # The page's top-level elements: headings, paragraphs, lists, tables,
        # and block quotes.
        def blocks
          @blocks ||= content_document.children.select(&:element?)
        end

        # The top-level elements other than headings and image-only paragraphs.
        def body_blocks
          blocks.reject { |b| heading?(b) || (b.name == 'p' && clean(b.text).empty?) }
        end

        def heading?(block)
          block.name.match?(/\Ah[1-6]\z/)
        end

        # A heading's text without its leading emoji.
        def heading_text(block)
          clean(block.text).sub(LEADING_SYMBOLS, '')
        end

        def folder
          parts = @page.url_path.to_s.split('/')
          parts.length > 1 ? parts.first : nil
        end

        def clean(text)
          text.to_s.gsub(/\s+/, ' ').strip
        end

        def sentence(text)
          text = clean(text)
          return '' if text.empty?
          text = text[0].upcase + text[1..]
          text.match?(/[.!?…]\z/) ? text : "#{text}."
        end

        def sentences(text)
          clean(text).split(SENTENCE_BREAK)
        end

        # Lowercases a heading word unless it is an acronym such as "AC".
        def lower_first(text)
          text = clean(text)
          return text if text.empty? || text[1]&.match?(/\p{Lu}/)
          text[0].downcase + text[1..]
        end

        # A paragraph's text without legal definitions such as '(the "Terms")'
        # and without an opening "This is self-explanatory." sentence.
        def prepare(text)
          clean(text).gsub(LEGAL_DEFINITION, '').sub(FILLER_SENTENCE, '')
        end

        # Whether a text can describe the page on its own.
        def usable_text?(text, block = nil, min_words: MIN_PROSE_WORDS)
          return false if text.nil? || text.empty? || text.split.length < min_words
          return false if text.match?(BARE_URL) || (block && code_only?(block)) || shouting?(text)
          return false if [LEGAL_TEXT, CROSS_REFERENCE, SIDE_NOTE, DANGLING_REFERENCE].any? { |p| text.match?(p) }
          !text.match?(DANGLING_START) || text.match?(SELF_REFERENCE)
        end

        # Whether most of a text's letters are capitals, as in a warning label.
        def shouting?(text)
          letters = text.scan(/\p{L}/)
          letters.length >= 12 && letters.count { |l| l.match?(/\p{Lu}/) } * 2 > letters.length
        end

        def code_only?(block)
          parts = block.children.reject { |c| (c.text? && c.text.strip.empty?) || c.name == 'br' }
          !parts.empty? && parts.all? { |c| c.name == 'code' }
        end

        # A text and what follows it. A text ending in a colon takes the names
        # or items of the list or table after it; without one, its colon
        # sentence is dropped or closed. A text without closing punctuation
        # takes the items of the list after it. Nil when nothing usable is
        # left.
        def complete_with_next(text, following)
          if text.end_with?(':')
            series = colon_series(text, following)
            series ? "#{text} #{series}." : close_colon(text, following)
          elsif text.match?(/\p{L}\z/) && following&.name == 'ul' && !list_headings?(following)
            items = list_items(following, first_case: true)
            items.empty? ? text : "#{text} #{items.join('; ')}."
          else
            text
          end
        end

        # What a colon text takes from the block after it: the names in a list
        # of links, the items of a list of labeled items or only their labels
        # when the items do not fit, the items of a bulleted list or of a
        # numbered list it calls "the following", or a table's first column.
        def colon_series(text, following)
          prefix = "#{text} "
          case following&.name
          when 'ul', 'ol'
            return nil if list_headings?(following)
            return name_series(link_names(following), prefix) if link_list?(following)
            labels = item_labels(following)
            if labels
              items = list_items(following, first_case: true).join('; ')
              fits = "#{prefix}#{items}.".length <= DESCRIPTION_MAX_LENGTH && !items.match?(%r{@|://})
              return fits ? items : name_series(labels, prefix)
            end
            return nil if following.name == 'ol' && !open_ended?(text)
            items = list_items(following, first_case: true)
            items.empty? ? nil : items.join('; ')
          when 'table'
            names = column_names(following)
            names.empty? ? nil : name_series(names, prefix)
          end
        end

        # The labels of a list whose every item is "**Label**: text" or
        # "**Label** — text".
        def item_labels(list)
          labels = list.css('> li').map do |li|
            node = first_node(li, %w[p span])
            return nil unless node && %w[strong b].include?(node.name) && own_text(li).match?(TERM_DEFINITION)
            clean(node.text).chomp(':')
          end
          labels.empty? ? nil : labels
        end

        # Whether a list's items are headings of the lists nested in them.
        def list_headings?(list)
          list.css('> li').all? { |li| own_text(li).end_with?(':') }
        end

        # Whether a colon sentence needs the list after it to make sense, as
        # "...the following:" and "...used to:" do.
        def open_ended?(text)
          last = sentences(text).last.to_s.chomp(':')
          last.match?(THE_FOLLOWING) || last.match?(TRAILING_WORD)
        end

        # A colon text with nothing to complete it: the sentences before the
        # colon sentence, or the colon sentence closed with a period. A lone
        # sentence that introduces a code block is not closed.
        def close_colon(text, following)
          parts = sentences(text)
          return parts[0..-2].join(' ') if parts.length > 1
          return text.sub(AS_FOLLOWS, '.') if text.match?(AS_FOLLOWS)
          return nil if open_ended?(text) || following&.name == 'pre' || (following&.name == 'p' && code_only?(following))
          text.sub(/:\z/, '.')
        end

        # 2. The ingress, completed by the block after it.
        def ingress_text
          content_document.css('blockquote').each do |quote|
            text = clean(quote.text)
            next unless text.match?(INGRESS_PREFIX)
            text = prepare(text.sub(INGRESS_PREFIX, ''))
            return usable_text?(text) ? complete_with_next(text, quote.next_element) : nil
          end
          nil
        end

        # 3. A caution or warning block quote that opens the page, without its
        # label and its pointers to other pages.
        def caution_text
          quote = blocks.find { |b| b.name != 'h1' }
          return nil unless quote&.name == 'blockquote'
          text = clean(quote.text)
          return nil unless text.match?(CAUTION_PREFIX)
          text = text.sub(CAUTION_PREFIX, '').sub(CAUTION_LABEL, '')
          text = prepare(sentences(text).reject { |s| s.match?(CAUTION_REFERENCE) }.join(' '))
          usable_text?(text) ? text : nil
        end

        # 4. Entry pages: "<Title>: GnollHack <kind>. <Description>. <Facts>."
        def entry_summary
          return nil unless entry_heading
          kind = heading_text(entry_heading)
          return nil if kind.empty?
          compose(sentence(entry_lead(kind)), entry_text(entry_heading), entry_facts)
        end

        # The first heading of an entry page, after any note block quotes,
        # when a header list of fields follows it, or a paragraph in a folder
        # without header fields. Index pages in the same folders have neither.
        def entry_heading
          return @entry_heading if defined?(@entry_heading)
          @entry_heading = nil
          return nil unless ENTRY_FOLDERS.include?(folder)
          start = blocks.drop_while { |b| b.name == 'h1' || (b.name == 'blockquote' && !clean(b.text).match?(INGRESS_PREFIX)) }
          heading, following = start
          return nil unless heading&.name == 'h2' && following
          header = following.name == 'ul' && following.css('> li').any? { |li| li.at_css('> strong') }
          plain = following.name == 'p' && !ENTRY_FACTS.key?(folder)
          @entry_heading = heading if header || plain
        end

        def entry_lead(kind)
          name = title.to_s.strip
          return "#{name}: GnollHack #{ENTRY_KINDS[folder]}" if kind.match?(GENERIC_KIND)
          case folder
          when 'Monsters' then "#{name}: GnollHack monster, #{lower_first(kind)}"
          when 'Items', 'Artifacts' then "#{name}: GnollHack #{item_kind(kind)}"
          when 'Conducts' then "#{name}: GnollHack conduct"
          else "#{name}: GnollHack #{kind.downcase}"
          end
        end

        # "Melee Weapon: Long sword - Artifact" becomes "artifact melee weapon
        # (long sword)"; "Spellbook - Level 4 movement spell" becomes
        # "spellbook (level 4 movement spell)". The subtype is left out when it
        # is the page title, a rock is named by its material, and every page in
        # Artifacts is an artifact.
        def item_kind(kind)
          main, extra = kind.split(/\s*-\s+(?=\S)/, 2)
          type, subtype = main.split(/:\s*/, 2)
          text = type.downcase
          if text == 'rock'
            material = entry_fields['Base material'].to_s
            text = 'gemstone' if material.casecmp?('Gemstone')
            text = 'worthless glass' if material.casecmp?('Glass')
          end
          text += " (#{subtype.downcase})" if subtype && !subtype.empty? && !subtype.casecmp?(title.to_s.strip)
          if extra.to_s.match?(/quest artifact/i)
            "quest artifact #{text}"
          elsif extra.to_s.match?(/artifact/i)
            "artifact #{text}"
          else
            text = "#{text} (#{lower_first(extra)})" if extra && !extra.empty?
            folder == 'Artifacts' ? "artifact #{text}" : text
          end
        end

        # The Description section, or else the paragraph right under the first
        # heading, or else the first powers or properties on an item page.
        def entry_text(heading)
          section = section_after(blocks.find { |b| b.name == 'h2' && heading_text(b).casecmp?('Description') })
          text = paragraphs_text(section.select { |b| b.name == 'p' })
          return text unless text.empty?

          paragraph = section_after(heading).find { |b| b.name == 'p' }
          return paragraphs_text([paragraph]) if paragraph
          return '' unless %w[Items Artifacts].include?(folder)

          (folder == 'Artifacts' ? ARTIFACT_POWER_SECTIONS : POWER_SECTIONS).each do |pattern|
            powers = blocks.find { |b| b.name == 'h2' && heading_text(b).match?(pattern) }
            list = section_after(powers).find { |b| %w[ol ul].include?(b.name) }
            next unless list
            items = list.css('> li').map { |li| [li, own_text(li).sub(/[.:;,]+\z/, '')] }
            items = items.reject { |_, text| text.empty? || text.match?(ROUTINE_PROPERTY) }
            return power_text(items.first(POWERS_SHOWN).map { |li, text| item_case(li, text) }) unless items.empty?
          end
          ''
        end

        # Paragraphs as sentences, each completed by the block after it.
        def paragraphs_text(paragraphs)
          paragraphs.filter_map do |p|
            text = prepare(p.text)
            text = complete_with_next(text, p.next_element) unless text.empty?
            text && sentence(text)
          end.reject(&:empty?).join(' ')
        end

        # Powers as one sentence each, or, when they all share a condition such
        # as "when worn", as one sentence of at most POWERS_JOINED_LENGTH
        # characters that gives it once at the end.
        def power_text(items)
          separate = items.map { |i| sentence(i) }.join(' ')
          condition = items.first[POWER_CONDITION]
          return separate unless condition && items.all? { |i| i.end_with?(condition) }
          stems = items.map { |i| i.delete_suffix(condition) }
          if stems.length > 1 && stems.all? { |s| s.match?(/\A\p{L}+ resistance\z/) }
            stems = ["#{series(stems.map { |s| s.delete_suffix(' resistance') })} resistance"]
          end
          joined = sentence("#{stems.join('; ')}#{condition}")
          joined.length <= POWERS_JOINED_LENGTH ? joined : separate
        end

        # A list item's text without the text of the lists nested in it.
        def own_text(item)
          clean(item.children.reject { |c| %w[ol ul].include?(c.name) }.map(&:text).join)
        end

        # The blocks between a heading and the next heading of any level.
        def section_after(heading)
          return [] unless heading
          blocks.drop(blocks.index(heading) + 1).take_while { |b| !heading?(b) }
        end

        # The "- **Field:** value" lines of an entry page's header list.
        def entry_fields
          @entry_fields ||= begin
            fields = {}
            header = entry_heading&.next_element
            header&.css('> li')&.each do |li|
              label = li.at_css('> strong')
              next unless label
              name = clean(label.text).chomp(':')
              value = clean(li.children.reject { |c| c == label || %w[ol ul].include?(c.name) }.map(&:text).join)
              fields[name] = value.sub(/\s*\(avg [^)]*\)/, '')
            end
            fields
          end
        end

        def entry_facts
          weapon = clean(entry_heading.text).match?(/weapon|ammunition/i)
          (ENTRY_FACTS[folder] || []).filter_map do |name, wording|
            value = entry_fields[name]
            next if value.nil? || value.empty? || value.casecmp?('none') || value.match?(ZERO_VALUE)
            next if name.start_with?('Base damage') && !weapon
            value = value.downcase if LOWERCASE_FIELDS.include?(name)
            value = MATERIAL_WORDS.fetch(value, value) if name == 'Material'
            value = value.sub(/\.0\z/, '') if name == 'Mana cost'
            wording % value
          end
        end

        # An entry summary within DESCRIPTION_MAX_LENGTH: the lead, then as
        # many sentences of the text and then as many facts as fit. A first
        # sentence too long to fit is cut, and no facts follow it.
        def compose(lead, text, facts)
          parts = sentences(text).reject { |s| s.match?(ENTRY_REFERENCE) }
          result = lead
          unless parts.empty?
            first = "#{result} #{parts.first}"
            return shorten_description(first) if first.length > DESCRIPTION_MAX_LENGTH
          end
          parts.each do |part|
            candidate = "#{result} #{part}"
            break if candidate.length > DESCRIPTION_MAX_LENGTH
            result = candidate
          end
          shown = []
          facts.each do |fact|
            break if "#{result} #{sentence((shown + [fact]).join(', '))}".length > DESCRIPTION_MAX_LENGTH
            shown << fact
          end
          result = "#{result} #{sentence(shown.join(', '))}" unless shown.empty?
          shorten_description(result)
        end

        # 5. Index pages, whose first list or table of links comes before any
        # prose: "<Title> in GnollHack: A, B, C, D, E, and 40 more." The names
        # come from every list and table of links on the page.
        def link_list_summary
          first = blocks.find { |b| link_list?(b) || prose?(b) }
          return nil unless first && link_list?(first)

          names = blocks.select { |b| link_list?(b) }.flat_map { |b| link_names(b) }
          prefix = "#{subject}: "
          "#{prefix}#{name_series(names, prefix)}."
        end

        # "<Title> <noun> in GnollHack", without "in GnollHack" when the title
        # already names it.
        def subject(noun = nil)
          text = noun ? "#{title} #{noun}" : title.to_s
          text.include?('GnollHack') ? text : "#{text} in GnollHack"
        end

        def list_rows(block)
          block.name == 'table' ? block.css('tbody tr') : block.css('> li')
        end

        # A list or table most of whose rows start with a link to a wiki page,
        # or every row of which starts with a link to any page when internal
        # is false; a one-row block must start with one.
        def link_list?(block, internal: true)
          return false unless %w[ul ol table].include?(block.name)
          rows = list_rows(block)
          return false if rows.empty?
          links = rows.count { |row| row_link(row, internal: internal) }
          return links == rows.length unless internal
          rows.length == 1 ? links == 1 : links * 2 > rows.length
        end

        # The link a list row or table row starts with: a link to a wiki page,
        # or to any page when internal is false.
        def row_link(row, internal: true)
          cell = row.name == 'tr' ? row.css('td').find { |td| !clean(td.text).empty? } : row
          node = cell && first_node(cell, %w[p span strong b em])
          return nil unless node&.name == 'a'
          node if internal ? internal_link?(node) : !node['href'].to_s.start_with?('#')
        end

        def internal_link?(link)
          href = link['href'].to_s
          !href.empty? && !href.match?(/\A(?:[a-z][a-z0-9+.-]*:|#)/i)
        end

        # The first child of a node that is not white space or an image,
        # looking inside the given wrapper elements.
        def first_node(node, wrappers)
          node.children.each do |child|
            next if child.text? && child.text.strip.empty?
            next if %w[img br].include?(child.name)
            return wrappers.include?(child.name) ? first_node(child, wrappers) : child
          end
          nil
        end

        def link_names(block, internal: true)
          list_rows(block).filter_map { |row| row_link(row, internal: internal)&.text }.map { |n| clean(n) }.reject(&:empty?)
        end

        def column_names(table)
          table.css('tbody tr').filter_map { |row| row.at_css('td') }.map { |cell| clean(cell.text) }.reject(&:empty?)
        end

        # A paragraph long and self-contained enough to describe the page.
        def prose?(block)
          return false unless block.name == 'p'
          text = prepare(block.text)
          text.length >= MIN_PROSE_LENGTH && usable_text?(text, block)
        end

        # Up to LIST_NAMES_SHOWN names and the number of the others, with
        # fewer names when "<prefix><names>." would not fit. A single other
        # name is shown rather than counted.
        def name_series(names, prefix = '')
          names = names.uniq(&:downcase)
          return '' if names.empty?
          options = [LIST_NAMES_SHOWN, names.length].min.downto(1).map do |count|
            rest = names.length - count
            rest <= 1 ? series(names) : series(names.first(count), "#{rest} more")
          end
          options.find { |o| "#{prefix}#{o}.".length <= DESCRIPTION_MAX_LENGTH } || options.last
        end

        # "A", "A and B", or "A, B, and C".
        def series(names, more = nil)
          words = more ? names + [more] : names
          return words.first if words.length == 1
          return "#{words[0]} and #{words[1]}" if words.length == 2
          separator = names.any? { |n| n.include?(',') } ? '; ' : ', '
          "#{words[0..-2].join(separator)}#{separator}and #{words.last}"
        end

        # The first sentences of a list's items without their closing
        # punctuation, ready to be joined with semicolons. Items after the
        # first, and the first too when first_case is set, start in lowercase
        # where item_case allows.
        def list_items(list, first_case: false)
          items = list.css('> li').map { |li| [li, sentences(own_text(li)).first.to_s.sub(/[.:;,]+\z/, '')] }
          items = items.reject { |_, text| text.empty? }
          items.each_with_index.map { |(li, text), i| i.zero? && !first_case ? text : item_case(li, text) }
        end

        # A list item in lowercase, unless it starts with a link or emphasis, a
        # word with inner capitals such as "iOS", a "Term: definition" label,
        # or a name the page capitalizes mid-sentence.
        def item_case(item, text)
          return text if text.empty?
          node = first_node(item, %w[p span])
          return text unless node&.text?
          word = text[/\A\S+/]
          return text if word[1..].to_s.match?(/\p{Lu}/) || text.match?(TERM_DEFINITION)
          return text if proper_names.include?(word[/\A\p{L}+/])
          text[0].downcase + text[1..]
        end

        # Capitalized words the page uses mid-sentence.
        def proper_names
          @proper_names ||= begin
            texts = content_document.css('p, td').map(&:text) + content_document.css('li').map { |li| own_text(li) }
            texts.flat_map { |t| clean(t).scan(/[\p{Ll},;] (\p{Lu}\p{Ll}+)/).flatten }.to_set
          end
        end

        # 6. The first top-level paragraph that can describe the page on its
        # own, completed by the block after it, and that ends as a sentence.
        def first_prose
          blocks.each do |block|
            next unless block.name == 'p'
            text = prepare(block.text)
            next unless usable_text?(text, block)
            text = complete_with_next(text, block.next_element)
            return text if text && text.length >= MIN_PROSE_LENGTH && text.match?(SENTENCE_END)
          end
          nil
        end

        # 7. On a page whose first content is a list or table: the names of
        # every list of links on the page, when the first list is one;
        # "<Title>: <step>; <step>; ..." from a numbered list, "<Title> <noun>
        # in GnollHack: <item>; <item>; ..." from a bulleted list, or the
        # first column of a table as a series of names.
        def first_list_summary
          first = body_blocks.first
          return nil unless first

          case first.name
          when 'ol', 'ul'
            if link_list?(first, internal: false)
              names = blocks.select { |b| link_list?(b, internal: false) }.flat_map { |b| link_names(b, internal: false) }
              prefix = "#{subject(FOLDER_NOUNS[folder])}: "
              return "#{prefix}#{name_series(names, prefix)}."
            end
            items = list_items(first, first_case: first.name == 'ul')
            return nil if items.empty? || !usable_text?(list_items(first).first, min_words: 1)
            "#{first.name == 'ol' ? title : subject(FOLDER_NOUNS[folder])}: #{items.join('; ')}."
          when 'table'
            names = column_names(first)
            return nil if names.empty?
            prefix = "#{subject(FOLDER_NOUNS[folder])}: "
            "#{prefix}#{name_series(names, prefix)}."
          end
        end

        # Text over DESCRIPTION_MAX_LENGTH is cut after its last sentence that
        # ends at or after SENTENCE_CUT_MIN characters, or else at its last
        # clause boundary at or after CLAUSE_CUT_MIN characters, or else at a
        # word outside a name, without a trailing function word or unclosed
        # bracket or quote.
        def shorten_description(text)
          return text if text.length <= DESCRIPTION_MAX_LENGTH
          head = text[0, DESCRIPTION_MAX_LENGTH + 2]
          ends = head.to_enum(:scan, SENTENCE_BREAK).map { Regexp.last_match.begin(0) }
          stop = ends.select { |i| i >= SENTENCE_CUT_MIN && i <= DESCRIPTION_MAX_LENGTH }.max
          return text[0, stop] if stop

          head = text[0, DESCRIPTION_MAX_LENGTH - 1]
          clause = head.to_enum(:scan, CLAUSE_BREAK).map { Regexp.last_match.begin(0) }.select { |i| i >= CLAUSE_CUT_MIN }.max
          cut = clause ? text[0, clause] : word_cut(text)
          loop do
            trimmed = drop_unclosed(cut.sub(/[\s,;:.–—-]+\z/, '').sub(TRAILING_WORD, ''))
            break if trimmed == cut
            cut = trimmed
          end
          "#{cut}…"
        end

        # A text cut at the last word that fits, before any capitalized name
        # the cut would split, such as "Sir Terry" of "Sir Terry Pratchett".
        def word_cut(text)
          cut = text[0, DESCRIPTION_MAX_LENGTH - 1]
          return cut unless cut.include?(' ')
          cut = cut.sub(/\s+\S*\z/, '')
          return cut unless text[cut.length..].to_s.match?(/\A\s+\p{Lu}/) && cut.match?(/\s\p{Lu}\S*\z/)
          cut.sub(/(?:\s+\p{Lu}\S*)+\z/, '')
        end

        # A text without its last opening bracket or quote and what follows
        # it, when that bracket or quote is not closed.
        def drop_unclosed(text)
          [['(', ')'], ['“', '”']].each do |open, close|
            text = text[0...text.rindex(open)] if text.count(open) > text.count(close)
          end
          text = text[0...text.rindex('"')] if text.count('"').odd?
          text.rstrip
        end
      end
    end
  end
