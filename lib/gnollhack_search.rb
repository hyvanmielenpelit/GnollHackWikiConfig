# Full-text search over a wiki's pages: plain text from Markdown source,
# length-preserving normalization, query parsing, an in-memory index, ranking,
# snippets with <mark>, text fragment links, exact-title lookup, title
# suggestions and "did you mean" titles.
#
# Every match offset is taken in normalized text, which has the same length as
# the text it came from, so it is also an offset in the original text.

require 'cgi'
require 'erb'
require 'set'
require 'yaml'
require_relative 'gnollhack_urls'

module GnollHackSearch
  # Ranking weights; see Index#search. TITLE_EQUALS also applies to a title
  # that differs from the query only by a plural ending.
  TITLE_EQUALS = 1000
  TITLE_STARTS = 300
  TITLE_EXACT = 60
  TITLE_PREFIX = 30
  HEADING = 15
  FOLDER = 5
  BODY = 10
  BODY_PHRASE = 20
  BM25_K1 = 1.2
  BM25_B = 0.75

  MAX_QUERY_LENGTH = 200
  MAX_TERMS = 10
  SNIPPET_WINDOW = 160
  SNIPPET_WINDOWS = 2
  # Match ranges considered per page when building a snippet.
  SNIPPET_RANGES = 200
  SUGGESTIONS = 8
  DID_YOU_MEAN = 5
  DID_YOU_MEAN_SIMILARITY = 0.3

  WORD = /[\p{L}\p{N}]+/
  NOT_WORD_BEFORE = '(?<![\p{L}\p{N}])'
  NON_ASCII = /[^\x00-\x7F]/
  ELLIPSIS = '…'
  FOLDER_SEPARATOR = ' › '

  # Characters normalize maps by hand; every other non-ASCII character is case
  # folded and stripped of combining marks.
  PUNCTUATION = {
    '’' => "'", '‘' => "'", 'ʼ' => "'",
    '‐' => '-', '‑' => '-', '–' => '-', '—' => '-', '−' => '-',
    '∕' => '/'
  }.freeze

  # Named entities the wiki uses beyond those CGI.unescapeHTML decodes.
  ENTITIES = {
    '&nbsp;' => ' ', '&times;' => '×', '&copy;' => '©', '&reg;' => '®', '&trade;' => '™',
    '&mdash;' => '—', '&ndash;' => '–', '&hellip;' => '…', '&minus;' => '−',
    '&lsquo;' => '‘', '&rsquo;' => '’', '&ldquo;' => '“', '&rdquo;' => '”',
    '&laquo;' => '«', '&raquo;' => '»', '&deg;' => '°', '&plusmn;' => '±', '&middot;' => '·',
    '&bull;' => '•', '&rarr;' => '→', '&larr;' => '←', '&harr;' => '↔',
    '&frac12;' => '½', '&frac14;' => '¼', '&frac34;' => '¾', '&shy;' => ''
  }.freeze
  ENTITY_PATTERN = Regexp.union(ENTITIES.keys)

  # Tags whose boundary separates words in rendered text.
  BLOCK_TAGS = %w[
    address article aside blockquote br caption center dd details div dl dt figcaption figure footer
    h1 h2 h3 h4 h5 h6 header hr img li main nav ol p pre section summary table tbody td tfoot th thead tr ul
  ].to_set.freeze
  IMAGE_EXTENSIONS = /\.(?:png|jpe?g|gif|webp|svg|avif|bmp|ico)\z/i
  MARKDOWN_EXTENSIONS = /\.(?:md|markdown|mkd|mkdn|mdown|mdwn)\z/i

  FOLDED = Hash.new do |cache, char|
    cache[char] = PUNCTUATION.fetch(char) do
      folded = char.downcase(:fold).unicode_normalize(:nfkd).gsub(/\p{Mn}/, '')
      folded.empty? ? char : folded[0]
    end
  end

  module_function

  # Lowercase, accent-free text of the same length as text: each character
  # maps to exactly one character.
  def normalize(text)
    lower = text.tr('A-Z', 'a-z')
    lower.ascii_only? ? lower : lower.gsub(NON_ASCII) { |char| FOLDED[char] }
  end

  # The form titles are compared in by the exact-title lookup and the
  # suggestions: normalized, runs of spaces and underscores as one space.
  def fold_title(text)
    normalize(text.to_s).gsub(/[ _]+/, ' ').strip
  end

  # Words of a normalized string, joined by one space.
  def word_key(normalized)
    normalized.scan(WORD).join(' ')
  end

  # The folder part of a page path for display: 'Items › Weapons'; '' at the
  # repository root.
  def folder_label(path)
    path.split('/')[0...-1].join(FOLDER_SEPARATOR)
  end

  # A document for Index.new, from a page's path, canonical URL and source.
  def document(path, url, source)
    title, headings, text = page_text(source, path)
    { path: path, url: url, title: title, headings: headings, text: text, folder: folder_label(path) }
  end

  # [title, headings, text] from a page's source. The title is what Gollum
  # shows with h1_title: the page's opening H1, else the front matter title,
  # else the file name. Markdown syntax and HTML tags are removed; their text
  # is kept. Every pass is linear in the size of the page.
  def page_text(source, path)
    src = source.to_s.dup.force_encoding(Encoding::UTF_8).scrub('').delete("\r")
    meta_title, src = front_matter(src)
    name = path.to_s.split('/').last.to_s.sub(GnollHackUrls::EXTENSION, '')

    unless path.to_s.match?(MARKDOWN_EXTENSIONS)
      return [meta_title || name, [], squish(decode(src))]
    end

    h1, headings, text = markdown_text(strip_comments(src))
    [h1 || meta_title || name, headings, text]
  end

  # [front matter title or nil, source without the front matter].
  def front_matter(src)
    return [nil, src] unless src.start_with?("---\n")
    close = src.index(/^(?:---|\.\.\.)[ \t]*$/, 4)
    return [nil, src] unless close
    yaml = src[4...close]
    rest = src[(src.index("\n", close) || src.length)..].to_s
    meta = begin
      YAML.safe_load(yaml)
    rescue StandardError, Psych::Exception
      nil
    end
    title = meta.is_a?(Hash) && meta['title'].is_a?(String) ? squish(decode(meta['title'])) : nil
    [title && !title.empty? ? title : nil, rest]
  end

  def strip_comments(src)
    return src unless src.include?('<!--')
    out = +''
    position = 0
    while (open = src.index('<!--', position))
      out << src[position...open] << ' '
      close = src.index('-->', open + 4)
      return out unless close
      position = close + 3
    end
    out << src[position..]
  end

  # [opening H1 or nil, headings, text] of Markdown without comments.
  def markdown_text(src)
    chunks = []
    headings = []
    h1 = nil
    fence = nil
    first_block = true
    paragraph = nil # index in chunks of the paragraph line a setext underline would turn into a heading

    src.split("\n", -1).each do |line|
      if fence
        if line.lstrip.start_with?(fence) && line.strip.delete(fence[0]).empty?
          fence = nil
        else
          chunks << [:code, line]
        end
        next
      end

      stripped = line.strip
      if (open = stripped[/\A(?:`{3,}|~{3,})/]) && line.match?(/\A {0,3}[`~]/)
        fence = open
        first_block = false
        paragraph = nil
        next
      end

      if stripped.empty?
        paragraph = nil
        next
      end

      if line.match?(/\A {0,3}#/) && (marker = stripped[/\A[#]{1,6}(?=[ \t]|\z)/])
        heading = atx_heading(stripped, marker.length)
        if marker.length == 1 && first_block && h1.nil?
          h1 = clean(heading)
        else
          headings << clean(heading)
          chunks << [:text, heading]
        end
        first_block = false
        paragraph = nil
        next
      end

      if paragraph && line.match?(/\A {0,3}(?:=+|-+)[ \t]*\z/)
        heading = chunks[paragraph][1]
        if stripped.start_with?('=') && paragraph.zero? && h1.nil? && chunks.length == 1
          h1 = clean(heading)
          chunks.pop
        else
          headings << clean(heading)
        end
        paragraph = nil
        next
      end

      if rule_or_separator?(stripped)
        first_block = false
        paragraph = nil
        next
      end
      next if stripped.match?(/\A\[[^\]\n]+\]:[ \t]*\S/) # link reference definition

      text = line.sub(/\A[ \t]*>[ \t>]*/, '')
      text = text.sub(/\A[ \t]*(?:[*+-]|\d{1,9}[.)])[ \t]+/, '').sub(/\A\[[ xX]\][ \t]+/, '')
      paragraph = text == line ? chunks.length : nil
      chunks << [:text, text]
      first_block = false
    end

    parts = chunks.chunk_while { |a, b| a[0] == b[0] }.map do |group|
      joined = group.map(&:last).join("\n")
      group.first[0] == :code ? joined : inline(joined)
    end
    [h1, headings.reject(&:empty?), squish(decode(parts.join("\n")))]
  end

  def clean(markdown)
    squish(decode(inline(markdown)))
  end

  def atx_heading(stripped, level)
    text = stripped[level..].to_s.strip
    if text.end_with?('#')
      without = text.sub(/#+\z/, '')
      text = without.rstrip if without.empty? || without.end_with?(' ', "\t")
    end
    text
  end

  # A thematic break, or a table's separator row.
  def rule_or_separator?(stripped)
    compact = stripped.delete(" \t")
    return true if compact.length >= 3 && compact.squeeze.length == 1 && '*-_'.include?(compact[0])
    compact.include?('-') && compact.include?('|') && compact.match?(/\A[|:-]+\z/)
  end

  # Inline Markdown and HTML to text. Wikilinks keep their text: [[Text|Target]]
  # gives Text, [[Target]] its last path segment; images keep their alt text.
  def inline(text)
    text = text.gsub(/\\([!-\/:-@\[-`{-~])/, '\1')
    text = text.gsub(/\[\[_TOC_[^\]\n]*\]\]/, ' ')
    text = text.gsub(/\[\[([^\]\n]*)\]\]/) { wikilink_text(Regexp.last_match(1)) }
    text = text.gsub(/!\[([^\]\n]*)\]\([^)\n]*\)/, '\1')
    text = text.gsub(/\[([^\]\n]*)\]\([^)\n]*\)/, '\1')
    text = text.gsub(/\[([^\]\n]*)\]\[[^\]\n]*\]/, '\1')
    text = text.gsub(/<\/?([A-Za-z][A-Za-z0-9]*)[^<>]*>/) { |tag| tag_text(tag, Regexp.last_match(1)) }
    text = text.gsub(/\*\*|__|~~/, '')
    text = text.delete('*`')
    text = text.gsub(/(?<![\p{L}\p{N}])_|_(?![\p{L}\p{N}])/, '')
    text.tr('|', ' ')
  end

  def wikilink_text(inner)
    parts = inner.split('|')
    first = parts.first.to_s.strip
    if first.match?(IMAGE_EXTENSIONS)
      alt = parts.find { |part| part.strip.start_with?('alt=') }
      return alt ? " #{alt.strip.delete_prefix('alt=')} " : ' '
    end
    return first if parts.length > 1
    target = first.sub(/#.*\z/, '')
    target.empty? ? first.delete_prefix('#') : target.split('/').last.to_s
  end

  def tag_text(tag, name)
    name = name.downcase
    if name == 'img'
      alt = tag[/\balt\s*=\s*"([^"]*)"/i, 1] || tag[/\balt\s*=\s*'([^']*)'/i, 1]
      return alt ? " #{alt} " : ' '
    end
    BLOCK_TAGS.include?(name) ? ' ' : ''
  end

  def decode(text)
    CGI.unescapeHTML(text.gsub(ENTITY_PATTERN, ENTITIES))
  end

  def squish(text)
    text.gsub(/\s+/, ' ').strip
  end

  # A parsed search query: positive terms, excluded terms, and the positive
  # words in order. A term is one word, or a phrase: a quoted string or a word
  # with punctuation inside, matched as its words in order.
  class Query
    Term = Struct.new(:words, :key, :pattern) do
      def phrase?
        words.length > 1
      end
    end

    attr_reader :raw, :terms, :excluded, :words, :text, :phrase_pattern

    def self.parse(string)
      new(string)
    end

    def initialize(string)
      @raw = string.to_s.dup.force_encoding(Encoding::UTF_8).scrub('')[0, MAX_QUERY_LENGTH]
      @terms = []
      @excluded = []
      count = 0
      @raw.scan(/(-?)"([^"]*)"?|(\S+)/) do |minus, quoted, bare|
        break if count >= MAX_TERMS
        negative = !minus.to_s.empty?
        source = quoted
        if bare
          negative = bare.length > 1 && bare.start_with?('-')
          source = negative ? bare[1..] : bare
        end
        words = GnollHackSearch.normalize(source.to_s).scan(WORD)
        next if words.empty?
        count += 1
        (negative ? @excluded : @terms) << Query.term(words)
      end
      @words = @terms.flat_map(&:words)
      @text = @words.join(' ')
      @phrase_pattern = @words.length > 1 ? Query.term(@words).pattern : nil
      [@terms, @excluded, @words].each(&:freeze)
      freeze
    end

    # Group 1 of the pattern is the word character after the match, if any: a
    # match without it ends at a word end.
    def self.term(words)
      body = words.map { |word| Regexp.escape(word) }.join('[^\p{L}\p{N}]+')
      source = "#{NOT_WORD_BEFORE}#{body}([\\p{L}\\p{N}])?".encode(Encoding::UTF_8)
      Term.new(words.freeze, words.max_by(&:length), Regexp.new(source)).freeze
    end

    def empty?
      @terms.empty?
    end
  end

  # The search index of one commit's pages. Read-only once built, except for
  # the "did you mean" trigrams, which are built on first use.
  class Index
    Doc = Struct.new(:path, :url, :title, :text, :folder, :n_title, :n_headings, :n_text, :n_folder,
                     :title_key, :length)

    EMPTY = { total: 0, results: [].freeze }.freeze

    attr_reader :size

    # Yields to other threads after each document, so a build on a background
    # thread does not hold up requests.
    def initialize(documents)
      @docs = documents.map do |d|
        Thread.pass
        text = d[:text].to_s
        n_text = GnollHackSearch.normalize(text)
        n_title = GnollHackSearch.normalize(d[:title].to_s)
        Doc.new(d[:path], d[:url], d[:title].to_s, text, d[:folder].to_s, n_title,
                GnollHackSearch.normalize(Array(d[:headings]).join("\n")), n_text,
                GnollHackSearch.normalize(d[:folder].to_s), GnollHackSearch.word_key(n_title),
                text.empty? ? 0 : text.count(' ') + 1).freeze
      end.freeze
      @size = @docs.length
      @average_length = @size.zero? ? 1.0 : [@docs.sum(&:length).to_f / @size, 1.0].max

      go = {}
      @docs.each do |doc|
        key = GnollHackSearch.fold_title(doc.title)
        go[key] = go.key?(key) ? nil : doc.url
      end
      @go = go.compact.freeze
      @titles = @docs.map { |doc| [GnollHackSearch.fold_title(doc.title), doc] }
                     .sort_by { |folded, doc| [doc.title.length, doc.title.downcase, folded] }.freeze
      @trigram_lock = Mutex.new
      @trigrams = nil
    end

    # { total:, results: [...] } for the query (a Query or a String), the
    # results from offset to offset + limit in rank order.
    def search(query, offset: 0, limit: 20)
      query = Query.parse(query) unless query.is_a?(Query)
      return EMPTY if query.empty? || @docs.empty?

      terms = query.terms.sort_by { |term| -term.key.length }
      matches = []
      @docs.each do |doc|
        hits = {}
        rejected = terms.any? do |term|
          hit = match(term, doc)
          hits[term] = hit if hit
          hit.nil?
        end
        next if rejected
        next if query.excluded.any? { |term| match(term, doc) }
        matches << [doc, hits]
      end
      return EMPTY if matches.empty?

      frequencies = query.terms.to_h { |term| [term, @docs.count { |doc| doc.n_text.include?(term.key) }] }
      scored = matches.map { |doc, hits| [score(query, doc, hits, frequencies), doc, hits] }
      scored.sort_by! { |score, doc, _| [-score, doc.title.length, doc.title.downcase, doc.path] }
      page = scored[offset.to_i.clamp(0, scored.length), limit.to_i.clamp(0, scored.length)] || []
      { total: scored.length, results: page.map { |score, doc, hits| result(query, doc, hits, score) }.freeze }
    end

    # The URL of the only page whose title equals the query when letter case,
    # spaces and underscores are ignored, else nil.
    def go_target(query)
      @go[GnollHackSearch.fold_title(query)]
    end

    # [[title, url], ...]: titles that start with the prefix, then titles with
    # a word that starts with it, each group shortest first, then
    # alphabetically.
    def suggest(prefix, limit: SUGGESTIONS)
      folded = GnollHackSearch.fold_title(prefix)
      return [] if folded.empty?
      word_start = /#{NOT_WORD_BEFORE}#{Regexp.escape(folded)}/
      starts = []
      inside = []
      @titles.each do |title, doc|
        next unless title.include?(folded)
        if title.start_with?(folded)
          starts << doc
          break if starts.length >= limit
        elsif inside.length < limit && title.match?(word_start)
          inside << doc
        end
      end
      (starts + inside).first(limit).map { |doc| [doc.title, doc.url] }
    end

    # [{ title:, url: }, ...]: titles most similar to the query by trigram
    # similarity, at least DID_YOU_MEAN_SIMILARITY.
    def did_you_mean(query, limit: DID_YOU_MEAN)
      wanted = GnollHackSearch.trigrams(GnollHackSearch.fold_title(query))
      return [] if wanted.empty?
      ranked = trigram_titles.filter_map do |grams, doc|
        shared = (grams & wanted).size
        next if shared.zero?
        similarity = shared.to_f / (grams.size + wanted.size - shared)
        [similarity, doc] if similarity >= DID_YOU_MEAN_SIMILARITY
      end
      ranked.sort_by { |similarity, doc| [-similarity, doc.title.length, doc.title.downcase] }
            .first(limit).map { |_, doc| { title: doc.title, url: doc.url } }
    end

    private

    def trigram_titles
      @trigram_lock.synchronize do
        @trigrams ||= @titles.map { |title, doc| [GnollHackSearch.trigrams(title), doc] }.freeze
      end
    end

    # { title: [count, exact], headings: count, text: [count, exact] } for a
    # term that matches the title, a heading or the text; nil otherwise.
    def match(term, doc)
      title = count(term, doc.n_title)
      headings = count(term, doc.n_headings)
      text = count(term, doc.n_text)
      return nil unless title || headings || text
      { title: title, headings: headings ? headings[0] : 0, text: text }
    end

    # [matches, whole-word matches] of the term in a normalized field, or nil.
    def count(term, field)
      return nil unless field.include?(term.key)
      total = 0
      exact = 0
      field.scan(term.pattern) do
        total += 1
        exact += 1 unless Regexp.last_match(1)
      end
      total.zero? ? nil : [total, exact]
    end

    def score(query, doc, hits, frequencies)
      score = 0.0
      if GnollHackSearch.same_but_plural?(doc.title_key, query.text)
        score += TITLE_EQUALS
      elsif doc.title_key.start_with?(query.text)
        score += TITLE_STARTS
      end
      query.terms.each do |term|
        hit = hits[term]
        if (title = hit[:title])
          score += title[1].positive? ? TITLE_EXACT : TITLE_PREFIX
        end
        score += HEADING if hit[:headings].positive?
        score += FOLDER if doc.n_folder.include?(term.key) && doc.n_folder.match?(term.pattern)
        next unless (text = hit[:text])
        tf = text[1] + (text[0] - text[1]) * 0.5
        df = [frequencies[term], 1].max
        idf = Math.log(1 + (@size - df + 0.5) / (df + 0.5))
        norm = BM25_K1 * (1 - BM25_B + BM25_B * doc.length / @average_length)
        score += BODY * idf * tf * (BM25_K1 + 1) / (tf + norm)
      end
      score += BODY_PHRASE if query.phrase_pattern && doc.n_text.match?(query.phrase_pattern)
      score.round(4)
    end

    def result(query, doc, hits, score)
      ranges = GnollHackSearch.ranges(doc.n_text, query.terms)
      snippet_html, snippet_text = GnollHackSearch.snippet(doc.text, ranges, query.terms.length)
      title_ranges = GnollHackSearch.ranges(doc.n_title, query.terms)
      {
        path: doc.path, url: doc.url, title: doc.title,
        title_html: GnollHackSearch.marked(doc.title, title_ranges, 0, doc.title.length),
        folder: doc.folder, snippet_html: snippet_html, snippet_text: snippet_text,
        fragment: GnollHackSearch.fragment(doc.text, doc.n_text, ranges.first),
        count: query.terms.sum { |term| hits[term][:text] ? hits[term][:text][0] : 0 },
        title_count: title_ranges.length, score: score
      }.freeze
    end
  end

  # True when two word keys are equal, or differ only by an "s" or "es" at
  # the end of one of them: "potion" and "potions".
  def same_but_plural?(a, b)
    return true if a == b
    long, short = a.length > b.length ? [a, b] : [b, a]
    return false unless long.start_with?(short)
    %w[s es].include?(long[short.length..])
  end

  # Character trigrams of a folded title, padded with spaces.
  def trigrams(folded)
    return Set.new if folded.empty?
    padded = " #{folded} "
    (0..padded.length - 3).each_with_object(Set.new) { |i, set| set << padded[i, 3] }
  end

  # Sorted, merged [start, end, terms] ranges of every term's matches in a
  # normalized string, at most SNIPPET_RANGES. A prefix match ends at the end
  # of the term, not of the word.
  def ranges(normalized, terms)
    found = []
    terms.each_with_index do |term, index|
      next unless normalized.include?(term.key)
      normalized.scan(term.pattern) do
        match = Regexp.last_match
        found << [match.begin(0), match.end(0) - (match[1] ? 1 : 0), index]
        break if found.length >= SNIPPET_RANGES * 2
      end
    end
    found.sort!
    merged = []
    found.each do |start, finish, index|
      last = merged.last
      if last && start <= last[1]
        last[1] = [last[1], finish].max
        last[2] |= [index]
      else
        merged << [start, finish, [index]]
      end
    end
    merged.first(SNIPPET_RANGES)
  end

  # [html, text]: up to SNIPPET_WINDOWS windows of about SNIPPET_WINDOW
  # characters around the densest groups of matches; a second window only
  # when the first lacks a term. Without matches, the start of the text.
  def snippet(text, ranges, term_count)
    return ['', ''] if text.empty?
    if ranges.empty?
      finish = text.length <= SNIPPET_WINDOW ? text.length : word_end_before(text, SNIPPET_WINDOW, 0)
      plain = text[0...finish]
      plain += ELLIPSIS if finish < text.length
      return [CGI.escapeHTML(plain), plain]
    end

    first = best_window(ranges, ranges.map { |r| r[2] }.flatten.uniq)
    windows = [first]
    missing = (0...term_count).to_a - first[2]
    if SNIPPET_WINDOWS > 1 && !missing.empty?
      candidates = ranges.select { |r| (r[1] <= first[0] || r[0] >= first[1]) && (r[2] & missing).any? }
      windows << best_window(candidates, missing) unless candidates.empty?
    end
    windows = windows.map { |window| expand(text, window) }.sort_by(&:first)
    windows = [[windows[0][0], windows[1][1]]] if windows.length > 1 && windows[1][0] <= windows[0][1]

    html = +''
    plain = +''
    windows.each_with_index do |(start, finish), i|
      html << ' ' << ELLIPSIS << ' ' if i.positive?
      plain << ' ' << ELLIPSIS << ' ' if i.positive?
      if i.zero? && start.positive?
        html << ELLIPSIS
        plain << ELLIPSIS
      end
      html << marked(text, ranges, start, finish)
      plain << text[start...finish]
      if i == windows.length - 1 && finish < text.length
        html << ELLIPSIS
        plain << ELLIPSIS
      end
    end
    [html, plain]
  end

  # [start, end, terms covered] of the run of ranges within one window that
  # covers the most wanted terms, then the most matches.
  def best_window(ranges, wanted)
    best = nil
    ranges.each_with_index do |range, i|
      j = i
      j += 1 while j + 1 < ranges.length && ranges[j + 1][1] - range[0] <= SNIPPET_WINDOW
      covered = ranges[i..j].flat_map { |r| r[2] }.uniq & wanted
      rank = [covered.length, j - i + 1]
      best = [rank, range[0], ranges[j][1], covered] if best.nil? || (rank <=> best[0]).positive?
    end
    best[1..]
  end

  # The [start, end] of a window of about SNIPPET_WINDOW characters around a
  # covered span, cut at word boundaries.
  def expand(text, (from, to))
    slack = [SNIPPET_WINDOW - (to - from), 0].max
    start = [from - [slack / 3, 50].min, 0].max
    finish = [start + [SNIPPET_WINDOW, to - start].max, text.length].min
    start = [[finish - SNIPPET_WINDOW, 0].max, from].min if finish == text.length
    start = word_start_after(text, start, from) if start.positive?
    finish = word_end_before(text, finish, to) if finish < text.length
    [start, finish]
  end

  # A word start at or after position, not after limit; else the word start
  # before position.
  def word_start_after(text, position, limit)
    return position if text[position - 1] == ' '
    space = text.index(' ', position)
    return space + 1 if space && space < limit
    back = text.rindex(' ', position)
    back ? back + 1 : 0
  end

  # A word end at or before position, not before limit; else the word end
  # after position.
  def word_end_before(text, position, limit)
    return position if text[position] == ' '
    space = text.rindex(' ', position)
    return space if space && space >= limit
    forward = text.index(' ', position)
    forward || text.length
  end

  # text[start...finish] as HTML with each range inside it in <mark>.
  def marked(text, ranges, start, finish)
    html = +''
    position = start
    ranges.each do |from, to, _|
      next if to <= start
      break if from >= finish
      from = [from, start].max
      to = [to, finish].min
      html << CGI.escapeHTML(text[position...from]) << '<mark>' << CGI.escapeHTML(text[from...to]) << '</mark>'
      position = to
    end
    html << CGI.escapeHTML(text[position...finish].to_s)
  end

  # A text fragment for the first match: '#:~:text=' and its whole words, with
  # up to three preceding words as prefix; '' without a match.
  def fragment(text, normalized, range)
    return '' unless range
    start, finish = range
    finish += 1 while finish < normalized.length && normalized[finish].match?(WORD)
    target = text[start...finish]
    before = text[[start - 120, 0].max...start]
    words = before.split(' ')
    words.shift if start > 120 && !before.start_with?(' ')
    prefix = words.last(3).join(' ')
    encoded = prefix.empty? ? '' : "#{fragment_encode(prefix)}-,"
    "#:~:text=#{encoded}#{fragment_encode(target)}"
  end

  # Percent-encoding for a text directive: '-', ',' and '&' are encoded too.
  def fragment_encode(text)
    ERB::Util.url_encode(text).gsub('-', '%2D')
  end
end
