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
  #   {{description}} - plain text, shortened to DESCRIPTION_MAX_LENGTH
  #                     characters, from the first of these that a page has:
  #                     1. its ingress (the first block quote starting with the
  #                        pointing-hand emoji);
  #                     2. on the home page, the site-wide text;
  #                     3. on an entry page in an ENTRY_FOLDERS folder, a summary
  #                        built from its first heading, its Description
  #                        section or first paragraph, and its header fields;
  #                     4. on a page whose first list or table of links comes
  #                        before any prose, the first link names and the
  #                        number of the others;
  #                     5. its first paragraph of prose;
  #                     6. on a page that opens with a list, its items;
  #                     7. the site-wide text, which non-page views also get.
  #
  # Gollum loads the Page view lazily; it must be loaded here before it is
  # extended, or this file would define a bare Page class in its place.

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
        INGRESS_PREFIX = /\A\u{1F449}\u{FE0F}?\s*/
        LEADING_SYMBOLS = /\A[^\p{L}\p{N}]+/
        MIN_PROSE_LENGTH = 40
        LIST_NAMES_SHOWN = 5
        POWERS_SHOWN = 3

        # Sections an item or artifact page lists its powers in, in order of
        # preference, and the routine artifact properties left out of them.
        POWER_SECTIONS = [/mythic powers/i, /conferred powers/i, /artifact properties/i, /item properties/i].freeze
        ROUTINE_PROPERTY = /\A(Alignment|Artifact|Intelligent|Attack bonus)\b/i

        LOWERCASE_FIELDS = %w[Alignment Material].freeze

        # Folders whose pages open with a "## <kind>" heading and a header list
        # of "- **Field:** value" lines.
        ENTRY_FOLDERS = %w[Monsters Items Artifacts Spells Skills Conducts].freeze

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
            text = ingress_text ||
                   (title.to_s.strip == SITE_NAME ? DEFAULT_DESCRIPTION : nil) ||
                   entry_summary ||
                   link_list_summary ||
                   first_prose ||
                   first_list_summary
            text ? shorten_description(text) : super
          end
        end

        private

        # The page's rendered content inside a wrapper, parsed as Gollum parses
        # it; a bare fragment can come back wrapped in a stray body element.
        def content_document
          @content_document ||= Nokogiri::HTML.fragment(%{<div id="seo-root">#{@content}</div>}, 'UTF-8').at_css('div#seo-root')
        end

        # The page's top-level elements: headings, paragraphs, lists, tables,
        # and block quotes.
        def blocks
          @blocks ||= content_document.children.select(&:element?)
        end

        # The top-level elements other than headings and image-only paragraphs.
        def body_blocks
          blocks.reject { |b| b.name.match?(/\Ah[1-6]\z/) || (b.name == 'p' && clean(b.text).empty?) }
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

        # Lowercases a heading word unless it is an acronym such as "AC".
        def lower_first(text)
          text = clean(text)
          return text if text.empty? || text[1]&.match?(/\p{Lu}/)
          text[0].downcase + text[1..]
        end

        def ingress_text
          content_document.css('blockquote').each do |quote|
            text = clean(quote.text)
            next unless text.match?(INGRESS_PREFIX)
            text = text.sub(INGRESS_PREFIX, '').strip
            return text unless text.empty?
          end
          nil
        end

        # 3. Entry pages: "GnollHack <kind>. <Description>. <Facts>."
        def entry_summary
          return nil unless ENTRY_FOLDERS.include?(folder)
          heading = blocks.first
          return nil unless heading&.name == 'h2'
          kind = clean(heading.text).sub(LEADING_SYMBOLS, '')
          return nil if kind.empty?

          parts = [sentence(entry_lead(kind)), sentence(entry_text(heading)), sentence(entry_facts)]
          parts.reject(&:empty?).join(' ')
        end

        def entry_lead(kind)
          case folder
          when 'Monsters' then "GnollHack monster: #{lower_first(kind)}"
          when 'Items', 'Artifacts' then "GnollHack #{item_kind(kind)}"
          when 'Conducts' then 'GnollHack conduct'
          else "GnollHack #{kind.downcase}"
          end
        end

        # "Melee Weapon: Long sword - Artifact" becomes "artifact melee weapon
        # (long sword)"; "Spellbook - Level 4 movement spell" becomes
        # "spellbook (level 4 movement spell)".
        def item_kind(kind)
          main, extra = kind.split(/\s*-\s+(?=\S)/, 2)
          type, subtype = main.split(/:\s*/, 2)
          text = type.downcase
          text += " (#{subtype.downcase})" if subtype && !subtype.empty?
          if extra.to_s.match?(/quest artifact/i)
            "quest artifact #{text}"
          elsif extra.to_s.match?(/artifact/i)
            "artifact #{text}"
          elsif extra && !extra.empty?
            "#{text} (#{lower_first(extra)})"
          else
            text
          end
        end

        # The Description section, or else the paragraph right under the first
        # heading, or else the first powers or properties on an item page.
        def entry_text(heading)
          section = section_after(blocks.find { |b| b.name == 'h2' && clean(b.text).casecmp?('Description') })
          text = section.select { |b| b.name == 'p' }.map { |b| clean(b.text) }.join(' ')
          return text unless text.empty?

          paragraph = section_after(heading).find { |b| b.name == 'p' }
          return clean(paragraph.text) if paragraph
          return '' unless %w[Items Artifacts].include?(folder)

          POWER_SECTIONS.each do |pattern|
            powers = blocks.find { |b| b.name == 'h2' && clean(b.text).match?(pattern) }
            list = section_after(powers).find { |b| %w[ol ul].include?(b.name) }
            next unless list
            items = list_items(list).reject { |i| i.match?(ROUTINE_PROPERTY) }
            return items.first(POWERS_SHOWN).map { |i| lower_first(i) }.join('; ') unless items.empty?
          end
          ''
        end

        # A list item's text without the text of the lists nested in it.
        def own_text(item)
          clean(item.children.reject { |c| %w[ol ul].include?(c.name) }.map(&:text).join)
        end

        # The blocks between a heading and the next heading of any level.
        def section_after(heading)
          return [] unless heading
          blocks.drop(blocks.index(heading) + 1).take_while { |b| !b.name.match?(/\Ah[1-6]\z/) }
        end

        def entry_facts
          weapon = clean(blocks.first.text).match?(/weapon|ammunition/i)
          fields = {}
          blocks.find { |b| b.name == 'ul' }&.css('> li')&.each do |li|
            label = li.at_css('> strong')
            next unless label
            name = clean(label.text).chomp(':')
            value = clean(li.children.reject { |c| c == label || %w[ol ul].include?(c.name) }.map(&:text).join)
            fields[name] = value.sub(/\s*\(avg [^)]*\)/, '')
          end
          (ENTRY_FACTS[folder] || []).filter_map do |name, wording|
            value = fields[name]
            next if value.nil? || value.empty? || value.casecmp?('none')
            next if name.start_with?('Base damage') && !weapon
            wording % (LOWERCASE_FIELDS.include?(name) ? value.downcase : value)
          end.join(', ')
        end

        # 4. Index pages, whose first list or table of links comes before any
        # prose: "<Title> in GnollHack: A, B, C, D, E, and 40 more." The names
        # come from every list and table of links on the page.
        def link_list_summary
          first = blocks.find { |b| link_list?(b) || prose?(b) }
          return nil unless first && link_list?(first)

          names = blocks.select { |b| link_list?(b) }.flat_map { |b| link_names(b) }.uniq
          "#{title} in GnollHack: #{name_series(names)}."
        end

        def list_rows(block)
          block.name == 'table' ? block.css('tbody tr') : block.css('> li')
        end

        # A list or table in which at least half of the rows carry a link.
        def link_list?(block)
          return false unless %w[ul ol table].include?(block.name)
          rows = list_rows(block)
          names = link_names(block)
          names.length >= 1 && names.length * 2 >= rows.length
        end

        def link_names(block)
          list_rows(block).filter_map { |row| row.at_css('a')&.text }.map { |n| clean(n) }.reject(&:empty?)
        end

        def prose?(block)
          block.name == 'p' && clean(block.text).length >= MIN_PROSE_LENGTH
        end

        # Up to LIST_NAMES_SHOWN names, and the number of the others.
        def name_series(names)
          shown = names.first(LIST_NAMES_SHOWN)
          rest = names.length - shown.length
          separator = shown.any? { |n| n.include?(',') } ? '; ' : ', '
          rest.positive? ? "#{shown.join(separator)}#{separator}and #{rest} more" : shown.join(separator)
        end

        # A list's items without their closing punctuation, ready to be joined
        # with semicolons; all but the first start in lowercase.
        def list_items(list)
          items = list.css('> li').map { |li| own_text(li).sub(/[.:;,]+\z/, '') }.reject(&:empty?)
          items.each_with_index.map { |item, i| i.zero? ? item : lower_first(item) }
        end

        # 5. The first top-level paragraph long enough to be prose. A paragraph
        # that ends in a colon takes the items of the list right after it, and
        # is skipped when no list follows.
        def first_prose
          blocks.each_with_index do |block, index|
            next unless prose?(block)
            text = clean(block.text)
            return text unless text.end_with?(':')

            following = blocks[index + 1]
            next unless following && %w[ul ol].include?(following.name)
            items = list_items(following)
            return "#{text} #{items.join('; ')}." unless items.empty?
          end
          nil
        end

        # 6. On a page whose first content is a list or table: "<Title> <noun>
        # in GnollHack: <item>; <item>; ..." from a list, or the first column
        # of a table as a series of names.
        def first_list_summary
          first = body_blocks.first
          return nil unless first
          noun = FOLDER_NOUNS[folder]
          subject = noun ? "#{title} #{noun}" : title

          case first.name
          when 'ul', 'ol'
            items = list_items(first)
            items.empty? ? nil : "#{subject} in GnollHack: #{lower_first(items.first)}#{items.drop(1).map { |i| "; #{i}" }.join}."
          when 'table'
            names = first.css('tbody tr').filter_map { |row| row.at_css('td') }.map { |cell| clean(cell.text) }.reject(&:empty?)
            names.empty? ? nil : "#{subject} in GnollHack: #{name_series(names)}."
          end
        end

        def shorten_description(text)
          return text if text.length <= DESCRIPTION_MAX_LENGTH
          cut = text[0, DESCRIPTION_MAX_LENGTH - 1]
          cut = cut.sub(/\s+\S*\z/, '') if cut.include?(' ')
          "#{cut.sub(/[\s,;:.–—-]+\z/, '')}…"
        end
      end
    end
  end
