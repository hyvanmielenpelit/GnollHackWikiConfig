# Clean page URLs for a Gollum wiki: each page's lowercase, hyphenated slug,
# derived from its file path, the index from slugs to page files, and the
# routing of a request path to a rewrite, a redirect or Gollum itself.

require 'erb'
require 'set'
require 'rack/utils'

module GnollHackUrls
  HOME_PAGE = 'Home.md'

  # First path segments that are Gollum's own routes.
  RESERVED = %w[gollum uploads].freeze

  # Letters that Unicode NFKD does not decompose into an ASCII base letter.
  TRANSLITERATIONS = {
    'ß' => 'ss', 'æ' => 'ae', 'œ' => 'oe', 'ø' => 'o',
    'ł' => 'l', 'đ' => 'd', 'ð' => 'd', 'þ' => 'th'
  }.freeze
  TRANSLITERATION_PATTERN = Regexp.union(TRANSLITERATIONS.keys)
  APOSTROPHES = /['‘’ʼ]/
  COMBINING_MARKS = /\p{Mn}/
  NON_SLUG = /[^a-z0-9]+/
  EDGE_HYPHENS = /\A-+|-+\z/

  PASSTHROUGH_PATHS = %w[/robots.txt /sitemap.xml].freeze

  module_function

  # The slug of one path segment: lowercase ASCII letters, digits and single
  # hyphens. Empty when nothing usable is left.
  def slug_segment(segment)
    s = segment.downcase
    unless s.ascii_only?
      s = s.gsub(TRANSLITERATION_PATTERN, TRANSLITERATIONS).unicode_normalize(:nfkd).gsub(COMBINING_MARKS, '')
    end
    s.gsub(APOSTROPHES, '').gsub(NON_SLUG, '-').gsub(EDGE_HYPHENS, '')
  end

  # The slug of a page path, without its extension: '' for Home, nil when a
  # segment has no usable characters.
  def slug(page_path)
    return '' if page_path == HOME_PAGE
    segments = page_path.split('/')
    return nil if segments.empty?
    segments[-1] = File.basename(segments[-1], File.extname(segments[-1]))
    slugs = segments.map { |s| slug_segment(s) }
    slugs.any?(&:empty?) ? nil : slugs.join('/')
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

  # The pages of one commit and their slugs. A page whose slug collides with
  # another's, has an empty segment, starts with a reserved segment, or equals
  # a non-page file's path ignoring case is a fallback page: it keeps its
  # escaped file path as its URL.
  class PageIndex
    attr_reader :pages, :fallbacks, :collisions

    def initialize(page_paths, other_paths = [])
      @pages = page_paths.map { |p| p.dup.freeze }.freeze
      @fallbacks = {}
      @collisions = {}
      @slug_to_page = {}
      @page_to_slug = {}

      by_slug = Hash.new { |h, k| h[k] = [] }
      @pages.each do |page|
        slug = GnollHackUrls.slug(page)
        if slug.nil?
          @fallbacks[page] = :empty_segment
        elsif RESERVED.include?(slug.split('/').first)
          @fallbacks[page] = :reserved
        else
          by_slug[slug] << page
        end
      end

      files = other_paths.map(&:downcase).to_set
      by_slug.each do |slug, group|
        if group.length > 1
          @collisions[slug] = group.freeze
          group.each { |page| @fallbacks[page] = :collision }
        elsif files.include?(slug)
          @fallbacks[group.first] = :file_conflict
        else
          @slug_to_page[slug] = group.first
          @page_to_slug[group.first] = slug
        end
      end

      @known = @pages.to_set
      @legacy_exact = {}
      legacy_folded = Hash.new { |h, k| h[k] = [] }
      @pages.each do |page|
        [page, page.sub(%r{\.[^./]+\z}, '')].uniq.each do |key|
          @legacy_exact[key] ||= page
          legacy_folded[key.downcase] << page
        end
      end
      @legacy_folded = legacy_folded.transform_values { |group| group.uniq.freeze }

      [@fallbacks, @collisions, @slug_to_page, @page_to_slug, @known, @legacy_exact, @legacy_folded].each(&:freeze)
      freeze
    end

    # The slug ('' for Home), or nil for a fallback page or an unknown path.
    def slug_for(page_path)
      @page_to_slug[page_path]
    end

    # '/' + slug; a fallback page's escaped file path; nil for an unknown path.
    def canonical_path(page_path)
      slug = @page_to_slug[page_path]
      return "/#{slug}" if slug
      @known.include?(page_path) ? "/#{GnollHackUrls.escape_path(page_path)}" : nil
    end

    def page_for_slug(slug)
      @slug_to_page[slug]
    end

    # The page whose path equals path, with or without its extension: an
    # exact match, else the only case-insensitive match, else nil.
    def page_for_legacy(path)
      exact = @legacy_exact[path]
      return exact if exact
      found = @legacy_folded[path.downcase]
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
      return redirect("/#{path.downcase}", query_string) if @index.page_for_slug(path.downcase)

      legacy = @index.page_for_legacy(path)
      slug = legacy && @index.slug_for(legacy)
      return redirect("/#{slug}", query_string) if slug
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
