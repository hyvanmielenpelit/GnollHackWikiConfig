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

    #default_keybinding: :vim,
    #default_keybinding: :emacs,

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

    # Command line only; not a wiki option.

    #-----------------------------------------------------------------------------
    # Launch Gollum in "console mode", with a predefined API.
    #
    # Equivalent to --irb

    # Command line only; not a wiki option.

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

    #show_local_time: true,

    #-----------------------------------------------------------------------------
    # Equivalent to --math. Set math parsing to either mathjax or katex (default)

    #math: :mathjax,
    math: :katex,

    #-----------------------------------------------------------------------------
    # Specify path to a custom MathJax or KaTeX configuration, committed to the
    # repository. --math sets it to math.config.js in the repository root.
    # Default: none.

    #math_config: [FILE],

    #-----------------------------------------------------------------------------
    # Render ```mermaid code blocks as diagrams. When on, every page loads the
    # Mermaid script; no wiki page uses Mermaid.
    # Default: true

    mermaid: false,

    #-----------------------------------------------------------------------------
    # The wiki's name, used in the feed of latest changes.
    # Default: 'Gollum Wiki'

    title: 'GnollHack Wiki',

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

    # Command line only; not a wiki option.

    #-----------------------------------------------------------------------------
    # Specify the git branch to serve.
    # Default: master or main, whichever exists.
    #
    # Equivalent to --ref [REF]

    # ref: "main",

    #-----------------------------------------------------------------------------
    # Use static assets.
    # Defaults to true, except in the gollum_development environment.

    # Equivalent to --static
    #static: true,

    # Equivalent to --no-static
    #static: false,

    #-----------------------------------------------------------------------------
    # Specify custom mustache template directory.
    #
    # Equivalent to --template-dir [PATH]

    #template_dir: ".gollum/templates/",

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
    # This is page metadata, not a wiki option: set it in a page's front
    # matter, or for every page through metadata: below.

    #metadata: { 'header_enum' => 'decimal-leading-zero' },

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

    #pagination_count: 15,
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
  # - /sitemap.xml lists every page with the date of its last commit, under
  #   its canonical URL (section "Clean page URLs and the rendered page
  #   cache"), with Home first as the site root. It is built from the served
  #   branch on first request and again after each new commit; a rebuild walks
  #   only the commits since the previous one.

  require 'cgi'
  require 'rugged'

  class GnollHackCrawlerSupport
    SITE_URL = 'https://wiki.gnollhack.com'

    # Repository folders whose files Gollum serves but which are not wiki pages.
    PRIVATE_FOLDERS = %w[.agents .claude].freeze

    # Pages left out of the sitemap: README.md is the repository's GitHub
    # front page. Home.md is listed first, as the site root.
    SITEMAP_EXCLUDED = %w[README.md].freeze
    HOME_PAGE = 'Home.md'

    ROBOTS_TXT = <<~TEXT
      # All crawlers, search engines, and AI agents may read the GnollHack Wiki.
      User-agent: *
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
      @sitemap_dates = nil
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
        repo = Rugged::Repository.new(current.path)
        begin
          oid = repo.rev_parse(current.ref).oid
          if @sitemap_commit != oid
            @sitemap_dates = last_commit_dates(repo, oid)
            @sitemap = build_sitemap(current, @sitemap_dates, GnollHackPageIndexCache.at(repo, oid))
            @sitemap_commit = oid
          end
          @sitemap
        ensure
          repo.close
        end
      end
    end

    # index is the GnollHackUrls::PageIndex of the commit being listed.
    def build_sitemap(current, dates, index)
      pages = current.pages.reject do |page|
        page.path.split('/').any? { |part| part.start_with?('.') } || SITEMAP_EXCLUDED.include?(page.path)
      end
      home, others = pages.partition { |page| page.path == HOME_PAGE }
      entries = (home + others).map do |page|
        path = index&.canonical_path(page.path) || "/#{page.escaped_url_path}"
        ["#{SITE_URL}#{path}", dates[page.path]]
      end

      urls = entries.map do |loc, time|
        lastmod = time ? "<lastmod>#{time.getutc.strftime('%Y-%m-%dT%H:%M:%SZ')}</lastmod>" : ''
        "  <url><loc>#{CGI.escapeHTML(loc)}</loc>#{lastmod}</url>"
      end
      %(<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n#{urls.join("\n")}\n</urlset>\n)
    end

    # The time of the newest commit that changed each path. When the served
    # branch has only moved forward since the previous build, only the new
    # commits are walked; otherwise the whole history is.
    def last_commit_dates(repo, oid)
      if @sitemap_dates && @sitemap_commit && repo.descendant_of?(oid, @sitemap_commit)
        @sitemap_dates.merge(commit_dates(repo, oid, @sitemap_commit))
      else
        commit_dates(repo, oid)
      end
    end

    # The time of the newest commit that changed each path, among the commits
    # reachable from push but not from hide.
    def commit_dates(repo, push, hide = nil)
      dates = {}
      walker = Rugged::Walker.new(repo)
      walker.sorting(Rugged::SORT_DATE)
      walker.push(push)
      walker.hide(hide) if hide
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
  # Versioned theme assets
  #
  # Template helper added for layout.mustache:
  #   {{#asset_url}}/.gollum/css/x.css{{/asset_url}} - the URL with
  #                     ?v=<content hash>, which changes whenever the file
  #                     does. Templates add
  #                     {{^asset_url}}/.gollum/css/x.css{{/asset_url}} as the
  #                     fallback for a config without the helper.
  #
  # Gollum serves /.gollum/ files from the wiki's working tree with only a
  # Last-Modified header. GnollHackAssetCaching gives them Cache-Control:
  # immutable for the current hash, revalidation for other CSS and JavaScript,
  # and one week for fonts and images. A file is hashed again when its mtime
  # or size changes, so a pulled theme change applies within a second, also to
  # pages in the rendered page cache (section "Clean page URLs and the
  # rendered page cache").

  require_relative 'lib/gnollhack_assets'

  class GnollHackAssetCaching
    # Resolved once, before any render changes the working directory. Like
    # bin/gollum, the working directory is the wiki when no path is set.
    WIKI_ROOT = File.expand_path(Precious::App.settings.respond_to?(:gollum_path) ? Precious::App.settings.gollum_path : Dir.pwd)

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      if env['REQUEST_METHOD'] == 'GET' && [200, 304].include?(status.to_i)
        policy = GnollHackAssets.cache_control(WIKI_ROOT, env['PATH_INFO'], env['QUERY_STRING'])
        if policy
          headers.keys.each { |key| headers.delete(key) if key.to_s.casecmp?('cache-control') }
          headers['cache-control'] = policy
        end
      end
      [status, headers, body]
    end
  end

  Precious::App.use GnollHackAssetCaching

  module Precious
    module Views
      class Layout
        def asset_url
          lambda { |text| GnollHackAssets.versioned_url(GnollHackAssetCaching::WIKI_ROOT, text.strip) }
        end
      end
    end
  end

  ##############################################################################
  # SEO: page titles and meta descriptions
  #
  # Template variables added for layout.mustache:
  #   {{page_title}}  - "<title> – GnollHack Wiki", or just "GnollHack Wiki".
  #   {{description}} - the page's meta description, chosen by the rules in
  #                     lib/gnollhack_seo.rb; non-page views get the site-wide
  #                     text.
  #
  # A page sets its own description with a "description:" key in its YAML
  # front matter. Keys in GnollHackSeo::METADATA_KEYS are left out of the
  # metadata table Gollum shows on a page. The wiki-wide metadata: option
  # would apply such a key to every page.
  #
  # Gollum loads the Page view lazily; it must be loaded here before it is
  # extended, or this file would define a bare Page class in its place.

  require_relative 'lib/gnollhack_seo'
  require 'gollum/views/page'

  module GnollHackSeoMetadata
    def display_metadata?
      return false if (metadata.keys - ['title', 'header_enum'] - GnollHackSeo::METADATA_KEYS).empty?
      super
    end
  end

  Gollum::Page.prepend(GnollHackSeoMetadata)

  # Gollum's Page#title parses the page with Nokogiri on every call, and a
  # request calls it several times.
  module GnollHackTitleMemo
    def title
      return @seo_title if defined?(@seo_title)
      @seo_title = super
    end
  end

  Precious::Views::Page.prepend(GnollHackTitleMemo)

  module Precious
    module Views
      class Layout
        def page_title
          GnollHackSeo.page_title(title)
        end

        def description
          GnollHackSeo::DEFAULT_DESCRIPTION
        end
      end

      class Page
        def description
          seo_describer.description
        end

        def rendered_metadata
          return '' unless page.display_metadata? && !metadata.empty?
          @rendered_metadata ||= table(metadata.reject { |k, _| GnollHackSeo::METADATA_KEYS.include?(k) })
        end

        private

        def seo_describer
          @seo_describer ||= GnollHackSeo::Describer.new(
            html: @content, url_path: @page.url_path, title: title,
            metadata: (@page.respond_to?(:metadata) ? @page.metadata : {})
          )
        end
      end
    end
  end

  ##############################################################################
  # Clean page URLs and the rendered page cache
  #
  # Clean URLs: every page is served at its title as Wikipedia writes it in a
  # URL: its file path with no extension, spaces written as underscores, the
  # capitalization of the file name kept, percent-encoded as MediaWiki encodes
  # it (lib/gnollhack_urls.rb); Home is at the site root. GnollHackCleanUrls
  # rewrites a slug request to the page's real path before Gollum sees it, so
  # titles, descriptions and everything else still come from the page itself.
  # An old URL (the file path, with or without its extension, with spaces
  # written as %20, in any letter case, with or without a trailing slash)
  # answers 301 to the slug. Wikilinks, og:url, <link rel="canonical"> and the
  # sitemap use the slug. A page whose slug would collide with another page's,
  # is an invalid title, starts with a reserved segment or equals a file's or
  # another page's path keeps its file URL, and is logged when the index is
  # built. Sub-pages,
  # dot-folders, Gollum's tool pages, raw and version URLs, images and theme
  # files are unchanged.
  #
  # Template helper added for layout.mustache:
  #   {{canonical_url}} - the page's absolute canonical URL; nil on non-page
  #                       views and for pages outside the index.
  #
  # The rendered page cache keeps the whole response of each page served at
  # its canonical URL (GET, no query string, 200, text/html) in memory and
  # answers the next request for it without entering Gollum. Every response
  # carries x-gnollhack-cache: hit or miss. The cache belongs to one epoch,
  # which grows whenever anything a page is rendered from changes:
  #   - the served commit (stat of the branch's ref files once a second, a
  #     Rugged verification when they changed and once a minute);
  #   - the template folder (its file list and each file's stat);
  #   - a /.gollum/ file whose versioned URL was rendered into a page
  #     (GnollHackAssets.outdated_urls).
  # A newer epoch empties the cache; a render that a change overtook is not
  # stored. config.rb, lib/ and the gems are loaded at startup, and a restart
  # empties the cache. Nothing is written to disk. Anything else a page's
  # HTML comes to depend on must be added to the environment token, or it is
  # served stale. GNOLLHACK_PAGE_CACHE=0 at startup turns the cache off.
  #
  # Paths are taken from the repository root: this wiki does not set
  # page_file_dir.

  require_relative 'lib/gnollhack_urls'
  require_relative 'lib/gnollhack_page_cache'

  module GnollHackPageIndexCache
    # Seconds between two checks of the served commit and the environment.
    CHECK_INTERVAL = 1
    # Seconds after which the commit is read with Rugged even when the ref
    # files look unchanged.
    VERIFY_INTERVAL = 60

    UNSET = Object.new.freeze

    @lock = Mutex.new
    @index = nil
    @oid = nil
    @epoch = 0
    @ref = nil
    @ref_files = nil
    @stat_usable = false
    @signature = nil
    @checked = nil
    @verified = nil
    @environment = UNSET

    class << self
      # [index, epoch], read together. The index is nil until the repository
      # has been read once.
      def snapshot
        @lock.synchronize do
          now = monotonic
          return [@index, @epoch] if @checked && now - @checked < CHECK_INTERVAL

          note_environment
          signature = @ref_files && GnollHackUrls.file_signature(@ref_files)
          if @stat_usable && signature == @signature && @verified && now - @verified < VERIFY_INTERVAL
            @checked = now
          else
            verify(signature)
          end
          [@index, @epoch]
        end
      end

      def current
        snapshot.first
      end

      # The index of a commit, read from an open repository.
      def at(repo, oid)
        @lock.synchronize { build(repo, oid) }
      end

      # The index for one Gollum::Wiki, which Gollum creates per request, so a
      # render uses one index throughout.
      def for_wiki(wiki)
        return wiki.instance_variable_get(:@gnollhack_page_index) if wiki.instance_variable_defined?(:@gnollhack_page_index)
        wiki.instance_variable_set(:@gnollhack_page_index, current)
      end

      # :stat when a due check stats the ref files, :verify when it opens the
      # repository.
      def gate
        @stat_usable ? :stat : :verify
      end

      # For the tools: the next snapshot checks again.
      def expire!
        @lock.synchronize { @checked = nil }
      end

      # For the tools: the next snapshot reads the repository and rebuilds the
      # index. The epoch is kept; the rebuild increments it.
      def reset!
        @lock.synchronize { @index = @oid = @signature = @checked = @verified = nil }
      end

      private

      def monotonic
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # Called with @lock held. Increments the epoch when the templates or a
      # rendered asset version changed since the previous check.
      def note_environment
        token = environment_token
        @epoch += 1 unless @environment.equal?(UNSET) || token == @environment
        @environment = token
      end

      def environment_token
        dir = Precious::App.settings.wiki_options[:template_dir]
        dir &&= File.expand_path(dir)
        files = dir ? Dir.children(dir).sort.map { |name| File.join(dir, name) } : []
        [files, GnollHackUrls.file_signature(files), GnollHackAssets.outdated_urls]
      rescue SystemCallError
        nil
      end

      # Called with @lock held. Reads the served commit with Rugged. The ref
      # files' signature is taken before the ref is resolved, so a ref that
      # moves meanwhile is verified again on the next check.
      def verify(signature)
        @ref ||= Gollum::Wiki.new(Precious::App.settings.gollum_path, Precious::App.settings.wiki_options).ref
        repo = Rugged::Repository.new(GnollHackAssetCaching::WIKI_ROOT)
        begin
          unless @ref_files
            @ref_files = [File.join(repo.path, 'refs', 'heads', @ref), File.join(repo.path, 'packed-refs')]
            signature = GnollHackUrls.file_signature(@ref_files)
          end
          @stat_usable = repo.references.exist?("refs/heads/#{@ref}") && signature.any?
          build(repo, repo.rev_parse(@ref).oid)
        ensure
          repo.close
        end
        @signature = signature
        @verified = @checked = monotonic
      rescue Rugged::Error, SystemCallError, Gollum::InvalidGitRepositoryError, Gollum::NoSuchPathError => e
        warn "GnollHack page index: #{e.class}: #{e.message}"
        @checked = monotonic
      end

      # Called with @lock held.
      def build(repo, oid)
        return @index if @index && @oid == oid
        paths = []
        repo.lookup(oid).tree.walk_blobs(:postorder) do |root, entry|
          paths << (String.new(root, encoding: Encoding::BINARY) << entry[:name].b).force_encoding(Encoding::UTF_8)
        end
        pages, others = GnollHackUrls.partition_paths(paths, Gollum::Markup.extensions,
                                                      Gollum::Page::SUBPAGENAMES.map { |name| name.to_s.capitalize })
        index = GnollHackUrls::PageIndex.new(pages, others)
        index.fallbacks.each { |page, reason| warn "GnollHack page index: #{page} keeps its file URL (#{reason})" }
        @index = index
        @oid = oid
        @epoch += 1
        index
      end
    end
  end

  GnollHackRenderedPages =
    ENV['GNOLLHACK_PAGE_CACHE'] == '0' ? nil : GnollHackPageCache::Store.new(max_bytes: 128 * 1024 * 1024)

  class GnollHackCleanUrls
    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless env['REQUEST_METHOD'] == 'GET'
      return @app.call(env) if GnollHackUrls.passthrough?(env['PATH_INFO'])
      # The epoch is read before Gollum reads anything for this request.
      index, epoch = GnollHackPageIndexCache.snapshot
      return @app.call(env) unless index

      action, target = GnollHackUrls::Router.new(index).route(env['PATH_INFO'], env['QUERY_STRING'])
      case action
      when :rewrite
        rewritten = env.merge('PATH_INFO' => target)
        if GnollHackRenderedPages && env['QUERY_STRING'].to_s.empty?
          GnollHackRenderedPages.fetch(epoch, target) { @app.call(rewritten) }
        else
          @app.call(rewritten)
        end
      when :redirect
        link = CGI.escapeHTML(target)
        body = %(<!DOCTYPE html>\n<title>Moved Permanently</title>\n<p>Moved to <a href="#{link}">#{link}</a>.</p>\n)
        [301, { 'location' => target, 'content-type' => 'text/html; charset=utf-8',
                'cache-control' => 'public, max-age=86400', 'content-length' => body.bytesize.to_s }, [body]]
      else
        @app.call(env)
      end
    end
  end

  Precious::App.use GnollHackCleanUrls

  # Links to existing pages point to the page's URL, percent-encoded. Gollum
  # joins it to base_path and appends the anchor; Home's empty URL renders
  # href="/".
  module GnollHackSlugLinks
    private

    def generate_link(path, name = nil, extra = nil, kind = nil)
      return super unless kind == :page_present
      url = GnollHackPageIndexCache.for_wiki(@markup.wiki)&.url_for(Rack::Utils.unescape_path(path))
      url ? super(url, name, extra, kind) : super
    end
  end

  Gollum::Filter::Tags.prepend(GnollHackSlugLinks)

  module Precious
    module Views
      class Layout
        def canonical_url
          nil
        end
      end

      class Page
        # A historical version gets the current page's URL.
        def canonical_url
          path = GnollHackPageIndexCache.for_wiki(@page.wiki)&.canonical_path(@page.path)
          path && "#{GnollHackCrawlerSupport::SITE_URL}#{path}"
        end
      end
    end
  end
