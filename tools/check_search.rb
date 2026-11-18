# Usage: ruby tools/check_search.rb <config.rb> <wiki> [--timing]
#
# Loads config.rb the way tools/check_urls.rb does, with the wiki's template
# folder, and checks the search through Precious::App. The wiki's
# search.mustache, searchbar.mustache and layout must be committed in <wiki>.
#
# Prints the pages left out of search by GnollHackUrls.github_file?, then
# checks, for a fixed list of queries: every result links to an indexed page
# (the router rewrites it) and never to an upload, a theme file, a dot-folder,
# a file with an extension or a README; the expected top result; snippets free
# of Markdown and HTML syntax; at least one <mark>. Then the Go redirect (also
# through Front Door), the results page's robots meta, Cache-Control, <search>
# landmark and label, the absence of Gollum's searchTerms, the suggestions
# JSON, /opensearch.xml and the layout's link to it, and the concurrency gate.
# Exits 1 on any failure.
#
# --timing also measures, best of seven unless stated, the budgets of the
# search: a query, a suggestion, a Go redirect, an index build (best of
# three), the index's retained memory, the GnollHackSearchRoutes pass-through
# on a page path, and a page render while a background build runs against
# the same render without one (medians). Exits 1 when one is over.
require 'cgi'
require 'json'
require 'benchmark'
require 'objspace'
require 'rexml/document'
require 'rack/mock'
require 'gollum/app'

config, wiki, mode = ARGV
abort 'Usage: ruby tools/check_search.rb <config.rb> <wiki> [--timing]' unless config && wiki
abort "Unknown option #{mode}" if mode && mode != '--timing'
Precious::App.set(:environment, :production)
Precious::App.set(:gollum_path, wiki)
Precious::App.set(:wiki_options, {})
load config
Precious::App.set(:wiki_options, Precious::App.settings.wiki_options.merge(template_dir: File.join(wiki, '.gollum/templates')))
$stdout.sync = true

site = GnollHackCrawlerSupport::SITE_URL
page_index = GnollHackPageIndexCache.current
abort 'The page index could not be built.' unless page_index
router = GnollHackUrls::Router.new(page_index)
req = Rack::MockRequest.new(Precious::App)

excluded = page_index.pages.select { |page| GnollHackUrls.github_file?(page) }.sort
puts "left out by github_file?: #{excluded.length}"
excluded.each { |page| puts "  #{page}" }

# Records failures per check and prints the first 20 of each.
class Checks
  def initialize
    @counts = Hash.new(0)
    @failures = Hash.new { |h, k| h[k] = [] }
  end

  def check(name, ok, detail)
    @counts[name] += 1
    @failures[name] << detail unless ok
  end

  def report
    @counts.each do |name, count|
      failures = @failures[name]
      puts "#{failures.empty? ? 'OK  ' : 'FAIL'} #{name}: #{count - failures.length} of #{count}"
      failures.first(20).each { |detail| puts "       #{detail}" }
    end
    @failures.values.all?(&:empty?)
  end
end

def body_of(res)
  res.body.to_s.dup.force_encoding('UTF-8')
end

def search_url(query, extra = '&fulltext=1')
  "/gollum/search?q=#{CGI.escape(query)}#{extra}"
end

# [[href, title html, snippet html], ...] from a results page.
def results_of(body)
  body.scan(%r{<li class="gh-search-result">\s*<h2><a href="([^"]*)">(.*?)</a></h2>.*?<p class="gh-search-snippet">(.*?)</p>}m)
end

def plain(html)
  CGI.unescapeHTML(html.gsub(%r{</?mark>}, ''))
end

checks = Checks.new
index = GnollHackSearchIndexCache.current
checks.check('the search index is built', index, 'GnollHackSearchIndexCache.current is nil')
abort 'The search index could not be built.' unless index
puts "search index: #{index.size} pages"

# Each query with a test of the top result's title, or nil for no expectation.
QUERIES = {
  'gnoll' => ->(t) { t.casecmp?('Gnoll') },
  'dragon' => ->(t) { t.downcase.include?('dragon') },
  'potion' => ->(t) { t == 'Potions' },
  'sharewithappdevelopers' => nil,
  'wand of' => ->(t) { t.downcase.start_with?('wand') },
  '"elven mithril"' => ->(t) { t.downcase.include?('elven mithril') },
  '-dragon gnoll' => ->(t) { !t.downcase.include?('dragon') },
  'HYVÄN' => nil,
  'wizard’s tower' => ->(t) { t == "Wizard's Tower" }
}.freeze
NOT_PAGES = %r{\A/(?:uploads|\.gollum|\.agents|\.claude|\.github)/}i
EXTENSION = /\.(?:md|markdown|webp|png|jpe?g|gif|svg|css|js|mustache|pdf|txt|ico|woff2)\z/i
SYNTAX = [/\[\[/, /\]\(/, /<!--/, /\{\{/, /\|\s*\|/, %r{</?(?:br|img|sup|td|tr|th|center|table|tbody|small|a|div|p|span|details|summary)\b}i].freeze

QUERIES.each do |query, expected|
  res = req.get(search_url(query))
  body = body_of(res)
  results = results_of(body)
  checks.check('results page answers 200', res.status == 200, "#{query}: #{res.status}")
  total = body[/(\d+) results?\b/, 1].to_i
  puts format('  %-26s %4d results, top: %s', query.inspect, total, results.first ? plain(results.first[1]) : '-')
  if expected
    top = results.first && plain(results.first[1])
    checks.check('expected top result', top && expected.call(top), "#{query}: #{top.inspect}")
  end
  checks.check('a query with results marks a match', results.empty? || body.include?('<mark>'), query)
  checks.check('HYVÄN finds Hyvän', total.positive?, "#{query}: #{total}") if query == 'HYVÄN'
  results.each do |href, title_html, snippet_html|
    url = CGI.unescapeHTML(href)
    path = url.sub(/#.*\z/, '')
    decoded = Rack::Utils.unescape_path(path).force_encoding('UTF-8')
    checks.check('result links to an indexed page', router.route(path, nil).first == :rewrite, "#{query}: #{url}")
    checks.check('result is not a file, upload or dot-folder', !decoded.match?(NOT_PAGES) && !decoded.match?(EXTENSION),
                 "#{query}: #{decoded}")
    checks.check('result is not a README', !decoded.match?(%r{(?:\A|/)readme\z}i), "#{query}: #{decoded}")
    checks.check('result link has a text fragment or none', url == path || url.include?('#:~:text='), "#{query}: #{url}")
    snippet = plain(snippet_html)
    bad = SYNTAX.find { |pattern| snippet.match?(pattern) }
    checks.check('snippet has no Markdown or HTML syntax', bad.nil?, "#{query} #{plain(title_html)}: #{snippet[0, 160]}")
  end
end

# Terms match at word starts: "otion" finds no "potion".
body = body_of(req.get(search_url('otion')))
checks.check('a query matches at word starts only', results_of(body).empty?, "otion: #{results_of(body).length} results")

res = req.get(search_url('Potions', ''))
checks.check('Go: an exact title answers 302 to its page', res.status == 302 && res.headers['location'] == '/Potions',
             "#{res.status} #{res.headers['location'].inspect}")
checks.check('Go: the 302 has Cache-Control: no-cache', res.headers['cache-control'] == 'no-cache', res.headers['cache-control'].inspect)
res = req.get(search_url('potions', '&page_num=2'))
checks.check('Go: not on a later page', res.status == 200, res.status.to_s)
res = req.get(search_url('Gnoll', ''))
checks.check('Go: an ambiguous title shows the results', res.status == 200, res.status.to_s)
front_door = { 'HTTP_X_AZURE_FDID' => '00000000-0000-0000-0000-000000000000', 'HTTP_HOST' => 'origin.invalid' }
res = req.get(search_url('Potions', ''), front_door)
checks.check('Go through Front Door has an absolute public Location', res.status == 302 && res.headers['location'] == "#{site}/Potions",
             "#{res.status} #{res.headers['location'].inspect}")

res = req.get(search_url('Potions'))
body = body_of(res)
checks.check('fulltext=1 shows the results', res.status == 200 && !results_of(body).empty?, res.status.to_s)
checks.check('results page is noindex', body.match?(%r{<meta name="robots" content="noindex, nofollow" ?/?>}), 'no robots meta')
checks.check('results page has Cache-Control: no-cache', res.headers['cache-control'] == 'no-cache', res.headers['cache-control'].inspect)
checks.check('results page has a <search> landmark and a label', body.include?('<search>') && body.include?('<label for="search-query"'),
             'missing <search> or label')
checks.check('results page sets no searchTerms', !body.include?('searchTerms'), 'searchTerms found')
checks.check('the field shows the query', body.include?('value="Potions"'), 'no value')
checks.check('results page title names the query', body.include?('<title>Search results for “Potions”'), body[%r{<title>[^<]*</title>}].inspect)

res = req.get(search_url('dragon', '&fulltext=1&page_num=2'))
body = body_of(res)
checks.check('page 2 starts at result 21 and links both ways',
             body.include?('start="21"') && body.include?('rel="prev"') && body.include?('page_num=1'),
             'start or links missing')

res = req.get(search_url('zzqqxx'))
checks.check('no results says so', body_of(res).include?('No pages contain all of these words.'), 'message missing')
res = req.get('/gollum/search?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E%22%27%26&fulltext=1')
checks.check('the query is escaped in the page', res.status == 200 && !body_of(res).include?('<script>alert(1)'), 'unescaped query')

res = req.get('/gollum/search/suggest?q=pot')
data = begin
  JSON.parse(res.body.to_s)
rescue JSON::ParserError
  nil
end
checks.check('suggestions are valid JSON with four arrays', data.is_a?(Array) && data.length == 4 && data[1..].all?(Array),
             res.body.to_s[0, 120])
checks.check('first suggestion starts with Pot', data.is_a?(Array) && data[1].is_a?(Array) && data[1].first.to_s.start_with?('Pot'),
             data.inspect[0, 120])
checks.check('suggestions have Cache-Control: public, max-age=300', res.headers['cache-control'] == 'public, max-age=300',
             res.headers['cache-control'].inspect)
checks.check('suggestion type is application/x-suggestions+json', res.headers['content-type'].to_s.start_with?('application/x-suggestions+json'),
             res.headers['content-type'].inspect)
if data.is_a?(Array) && data[3].is_a?(Array)
  data[3].each do |url|
    path = url.delete_prefix(site)
    checks.check('suggestion URLs are canonical page URLs', url.start_with?(site) && router.route(path, nil).first == :rewrite, url)
  end
end
short = JSON.parse(req.get('/gollum/search/suggest?q=p').body.to_s)
checks.check('a one-letter prefix gets no suggestions', short[1].empty?, short.inspect)

res = req.get('/opensearch.xml')
templates = begin
  doc = REXML::Document.new(res.body.to_s)
  REXML::XPath.match(doc, '//*[local-name()="Url"]').map { |u| [u.attributes['type'], u.attributes['template']] }.to_h
rescue REXML::ParseException
  {}
end
checks.check('/opensearch.xml has both Url templates',
             templates['text/html'] == "#{site}/gollum/search?q={searchTerms}" &&
               templates['application/x-suggestions+json'] == "#{site}/gollum/search/suggest?q={searchTerms}",
             templates.inspect)
checks.check('/opensearch.xml type and Cache-Control',
             res.headers['content-type'].to_s.start_with?('application/opensearchdescription+xml') &&
               res.headers['cache-control'] == 'public, max-age=3600',
             "#{res.headers['content-type']} #{res.headers['cache-control']}")
home = body_of(req.get('/'))
checks.check('the layout links /opensearch.xml', home.include?('rel="search" type="application/opensearchdescription+xml"'), 'no link')
checks.check('the layout loads gnollhack-search.js deferred', home.match?(%r{<script defer src="/\.gollum/js/gnollhack-search\.js\?v=\h+"}),
             home[/<script[^>]*gnollhack-search[^>]*>/].inspect)
checks.check('a page has no query in the search field', home.include?('id="search-query"') && !home.match?(/id="search-query"[^>]*value="[^"]+"/m),
             'value set')

# The gate, with no wait, under four parallel searches.
gate = GnollHackSearchRoutes::GATE
wait = GnollHackSearchRoutes::WAIT
GnollHackSearchRoutes.send(:remove_const, :WAIT)
GnollHackSearchRoutes.const_set(:WAIT, 0)
statuses = Array.new(4) { |i| Thread.new { Rack::MockRequest.new(Precious::App).get(search_url(%w[gnoll dragon potion wand][i])).status } }.map(&:value)
GnollHackSearchRoutes.send(:remove_const, :WAIT)
GnollHackSearchRoutes.const_set(:WAIT, wait)
checks.check('parallel searches answer 200 or 503 and free every slot', statuses.all? { |s| [200, 503].include?(s) } && gate.busy.zero?,
             "statuses #{statuses.inspect}, busy #{gate.busy}")
puts "gate: #{statuses.inspect}"
res = Rack::MockRequest.new(GnollHackSearchRoutes.new(->(_) { [200, {}, ['x']] })).get('/gollum/search?q=x&fulltext=1')
checks.check('a free gate passes the request', res.status == 200, res.status.to_s)

failed = !checks.report

if mode == '--timing'
  def best_of(repeats, count = 1)
    Array.new(repeats) { Benchmark.realtime { count.times { yield } } / count * 1000 }.min
  end

  def median(values)
    values.sort[values.length / 2]
  end

  figures = {}
  queries = QUERIES.keys
  figures[:query] = queries.map { |q| best_of(7) { index.search(q) } }.max
  figures[:query_request] = queries.map { |q| best_of(7) { req.get(search_url(q)) } }.max
  figures[:suggest] = %w[pot dra gno wa].map { |q| best_of(7, 20) { index.suggest(q) } }.max
  figures[:suggest_request] = best_of(7, 20) { req.get('/gollum/search/suggest?q=pot') }
  figures[:go] = best_of(7, 20) { index.go_target('Potions') }
  figures[:go_request] = best_of(7, 20) { req.get(search_url('Potions', '')) }

  pages, _, oid = GnollHackPageIndexCache.state
  figures[:build] = best_of(3) { GnollHackSearchIndexCache.build(pages, oid) }
  GC.start
  before = ObjectSpace.memsize_of_all
  kept = GnollHackSearchIndexCache.build(pages, oid)
  GC.start
  figures[:memory_mb] = (ObjectSpace.memsize_of_all - before) / 1024.0 / 1024
  kept = nil

  noop = ->(_env) { [200, {}, []] }
  layer = GnollHackSearchRoutes.new(noop)
  page = pages.pages.sort.find { |p| pages.slug_for(p) && !pages.slug_for(p).empty? }
  page_env = Rack::MockRequest.env_for(pages.canonical_path(page))
  figures[:pass_through] = best_of(7, 50_000) { layer.call(page_env) }

  # Renders of one page with the page cache emptied each time, alone and
  # while a build runs on a low-priority thread, as GnollHackSearchIndexCache
  # starts it. The two alternate, so a machine that slows down for a while
  # affects both alike.
  render = lambda do
    GnollHackRenderedPages&.clear
    Benchmark.realtime { Precious::App.call(page_env.dup) } * 1000
  end
  render.call
  alone = []
  during = []
  7.times do
    alone << render.call
    busy = true
    builder = Thread.new { GnollHackSearchIndexCache.build(pages, oid) while busy }
    builder.priority = -1
    sleep 0.05
    during << render.call
    busy = false
    builder.join
  end
  figures[:render] = median(alone)
  figures[:render_during_build] = median(during)

  puts "page: #{pages.canonical_path(page)}"
  figures.each { |name, value| puts format('%-20s %10.4f %s', name, value, name == :memory_mb ? 'MB' : 'ms') }
  limits = { query: 50, suggest: 10, go: 10, go_request: 10, build: 3000, memory_mb: 25, pass_through: 0.005 }
  limits.each do |name, limit|
    next unless figures[name] > limit
    puts "FAIL #{name} #{figures[name].round(4)} is over #{limit}"
    failed = true
  end
  if figures[:render_during_build] > figures[:render] * 1.25
    puts "FAIL render during a build #{figures[:render_during_build].round(1)} ms is over 125% of #{figures[:render].round(1)} ms"
    failed = true
  end
end

exit(failed ? 1 : 0)
