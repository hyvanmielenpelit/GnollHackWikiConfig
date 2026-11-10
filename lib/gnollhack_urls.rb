# Clean page URLs for a Gollum wiki: each page's title in the form Wikipedia
# (MediaWiki) writes it in a URL, derived from its file path, the index from
# titles to page files, and the routing of a request path to a rewrite, a
# redirect or Gollum itself.
#
# A slug is a page's decoded URL title: its file path without the extension,
# spaces written as underscores, the capitalization and every other character
# of the file name kept. url_path percent-encodes it for a URL; the router
# compares decoded paths, so every encoding of a slug reaches its page.

require 'erb'
require 'set'
require 'rack/utils'

module GnollHackUrls
  HOME_PAGE = 'Home.md'

  # First path segments that are Gollum's own routes, compared ignoring case.
  RESERVED = %w[gollum uploads].freeze

  # A page file's extension. Not File.extname, which on Windows reads 'A:B.md'
  # as a drive-relative path.
  EXTENSION = %r{\.[^./]+\z}
  SEPARATORS = /[ _]+/
  # What MediaWiki forbids in a title, and a percent-escape, which would
  # decode ambiguously.
  INVALID_TITLE = /[#<>\[\]|{}\p{Cc}]|%\h\h/

  # The characters MediaWiki's wfUrlencode leaves unencoded beyond those
  # ERB::Util.url_encode leaves. ':' is not among them: Gollum passes every
  # wikilink through Pathname#cleanpath, which on Windows cuts a path at a
  # colon and drops a final dot, so ':' stays %3A and a final '.' is %2E.
  URL_KEPT = {
    '%3B' => ';', '%40' => '@', '%24' => '$', '%21' => '!', '%2A' => '*',
    '%28' => '(', '%29' => ')', '%2C' => ',', '%2F' => '/'
  }.freeze
  URL_KEPT_PATTERN = Regexp.union(URL_KEPT.keys)

  PASSTHROUGH_PATHS = %w[/robots.txt /sitemap.xml].freeze

  module_function

  # The slug of a page path: '' for Home, nil when the path is not a valid
  # title (no segment, an empty segment, a segment that starts with '.', or a
  # character MediaWiki forbids).
  def slug(page_path)
    return '' if page_path == HOME_PAGE
    segments = page_path.sub(EXTENSION, '').split('/', -1).map do |segment|
      segment.gsub(SEPARATORS, '_').delete_prefix('_').delete_suffix('_')
    end
    return nil if segments.empty? || segments.any? { |s| s.empty? || s.start_with?('.') }
    title = segments.join('/')
    title.match?(INVALID_TITLE) ? nil : title
  end

  # A slug as it appears in a URL, always ASCII. Rack::Utils.unescape_path
  # turns it back into the slug.
  def url_path(slug)
    url = ERB::Util.url_encode(slug).gsub(URL_KEPT_PATTERN, URL_KEPT)
    url.end_with?('.') ? "#{url.delete_suffix('.')}%2E" : url
  end

  # The form request paths and file paths are compared in when letter case,
  # spaces and underscores are ignored.
  def fold(path)
    path.tr(' ', '_').squeeze('_').downcase
  end

  # A path escaped the way Gollum's escaped_url_path escapes it.
  def escape_path(path)
    ERB::Util.url_encode(path).gsub('%2F', '/')
  end

  # True for request paths that can never be a page: Gollum's own routes,
  # dot-folders, robots.txt and the sitemap.
  def passthrough?(path_info)
    path = path_info.to_s
    return true if PASSTHROUGH_PATHS.include?(path)
    segments = path.split('/').reject(&:empty?)
    return false if segments.empty?
    RESERVED.include?(segments.first) || segments.any? { |s| s.start_with?('.') }
  end

  # [page_paths, other_paths]: paths with a page extension that are not
  # sub-pages (_Sidebar, _Footer and the like, matched by prefix), and every
  # other file. Paths with a segment that starts with '.' are in neither.
  def partition_paths(paths, extensions, sub_page_names)
    extensions = extensions.map(&:to_s).to_set
    sub_page = /\A_(?:#{sub_page_names.map { |n| Regexp.escape(n.to_s) }.join('|')})/
    pages = []
    others = []
    paths.each do |path|
      next if path.start_with?('.') || path.include?('/.')
      name = File.basename(path)
      if extensions.include?(File.extname(name).delete_prefix('.')) && !name.match?(sub_page)
        pages << path
      else
        others << path
      end
    end
    [pages, others]
  end

  # [mtime in nanoseconds, size] for each file, or nil for a file that cannot
  # be read. Compare two signatures with ==.
  def file_signature(files)
    files.map do |file|
      stat = File.stat(file)
      [stat.mtime.to_i * 1_000_000_000 + stat.mtime.nsec, stat.size]
    rescue SystemCallError
      nil
    end
  end

  # The pages of one commit and their slugs. A page whose path is not a valid
  # title (:invalid_title), whose slug starts with a reserved segment
  # (:reserved), equals another page's slug ignoring case (:collision, the
  # whole group), or equals the path of any file, a page or not, ignoring case
  # (:file_conflict) is a fallback page: it keeps its escaped file path as its
  # URL.
  class PageIndex
    attr_reader :pages, :fallbacks, :collisions

    def initialize(page_paths, other_paths = [])
      @pages = page_paths.map { |p| p.dup.freeze }.freeze
      @fallbacks = {}
      @collisions = {}
      @slug_to_page = {}
      @page_to_slug = {}
      @page_to_url = {}

      slugs = {}
      by_folded_slug = Hash.new { |h, k| h[k] = [] }
      @pages.each do |page|
        slug = GnollHackUrls.slug(page)
        if slug.nil?
          @fallbacks[page] = :invalid_title
        elsif RESERVED.include?(slug.split('/').first.to_s.downcase)
          @fallbacks[page] = :reserved
        else
          slugs[page] = slug
          by_folded_slug[slug.downcase] << page
        end
      end

      files = (other_paths + @pages).map(&:downcase).to_set
      by_folded_slug.each do |folded, group|
        if group.length > 1
          @collisions[folded] = group.freeze
          group.each { |page| @fallbacks[page] = :collision }
        elsif files.include?(folded)
          @fallbacks[group.first] = :file_conflict
        else
          page = group.first
          slug = slugs[page].freeze
          @slug_to_page[slug] = page
          @page_to_slug[page] = slug
          @page_to_url[page] = GnollHackUrls.url_path(slug).freeze
        end
      end

      @known = @pages.to_set
      # A page's full path wins over another page's path without extension.
      @legacy_exact = {}
      @pages.each { |page| @legacy_exact[page] = page }
      @pages.each { |page| @legacy_exact[page.sub(EXTENSION, '')] ||= page }
      legacy_folded = Hash.new { |h, k| h[k] = [] }
      @pages.each do |page|
        keys = [GnollHackUrls.fold(page), GnollHackUrls.fold(page.sub(EXTENSION, ''))]
        keys << @page_to_slug[page].downcase if @page_to_slug[page]
        keys.uniq.each { |key| legacy_folded[key] << page }
      end
      @legacy_folded = legacy_folded.transform_values { |group| group.uniq.freeze }

      [@fallbacks, @collisions, @slug_to_page, @page_to_slug, @page_to_url, @known, @legacy_exact,
       @legacy_folded].each(&:freeze)
      freeze
    end

    # The decoded slug ('' for Home), or nil for a fallback page or an unknown
    # path.
    def slug_for(page_path)
      @page_to_slug[page_path]
    end

    # The slug as it appears in a URL ('' for Home), or nil for a fallback page
    # or an unknown path.
    def url_for(page_path)
      @page_to_url[page_path]
    end

    # '/' + url_for; a fallback page's escaped file path; nil for an unknown
    # path.
    def canonical_path(page_path)
      url = @page_to_url[page_path]
      return "/#{url}" if url
      @known.include?(page_path) ? "/#{GnollHackUrls.escape_path(page_path)}" : nil
    end

    # The page whose slug is exactly the decoded slug given.
    def page_for_slug(slug)
      @slug_to_page[slug]
    end

    # The page that a decoded request path names in an old or variant form:
    # its path with or without its extension exactly, else the only page
    # whose path, path without extension or slug equals it when letter case,
    # spaces and underscores are ignored, else nil.
    def page_for_legacy(path)
      exact = @legacy_exact[path]
      return exact if exact
      found = @legacy_folded[GnollHackUrls.fold(path)]
      found && found.length == 1 ? found.first : nil
    end

    def home?
      @known.include?(HOME_PAGE)
    end
  end

  # Routes a request path to [:pass], [:rewrite, path_info] or
  # [:redirect, location].
  class Router
    def initialize(index)
      @index = index
    end

    def route(path_info, query_string)
      path = Rack::Utils.unescape_path(path_info.to_s).dup.force_encoding('UTF-8')
      return [:pass] unless path.valid_encoding?
      path = path.squeeze('/').delete_prefix('/')
      trailing = path.end_with?('/')
      path = path.sub(%r{/+\z}, '')

      return [:pass] if GnollHackUrls.passthrough?("/#{path}")
      if path.empty?
        return @index.home? ? rewrite(HOME_PAGE) : [:pass]
      end

      page = trailing ? nil : @index.page_for_slug(path)
      return page ? rewrite(page) : [:pass] if raw?(query_string)
      return rewrite(page) if page

      # A canonical path decodes to an exact slug, so a redirect never chains.
      legacy = @index.page_for_legacy(path)
      return redirect(@index.canonical_path(legacy), query_string) if legacy && @index.slug_for(legacy)
      [:pass]
    end

    private

    def rewrite(page)
      [:rewrite, "/#{GnollHackUrls.escape_path(page)}"]
    end

    def redirect(location, query_string)
      query = query_string.to_s
      [:redirect, query.empty? ? location : "#{location}?#{query}"]
    end

    def raw?(query_string)
      query = query_string.to_s
      return false if query.empty?
      Rack::Utils.parse_query(query).key?('raw')
    rescue StandardError
      false
    end
  end
end
