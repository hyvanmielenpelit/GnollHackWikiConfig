# Usage: ruby tools/check_urls.rb <config.rb> <wiki> [--crawl | --timing]
#
# Loads config.rb the way tools/dump_descriptions.rb does and prints
# page path <TAB> canonical URL for every indexed page, then the fallback
# pages with their reason. Exits 1 when there are fallback pages, or when a
# [[Home]] wikilink does not render as href="/".
#
# --crawl requests every indexed page through Precious::App: the old URL,
# with and without its extension, and the canonical path in lowercase each
# answer 301 to the canonical path, except a form that decodes to the
# canonical path (the same URL in another encoding, which answers 200); the
# canonical path answers 200 with <link rel="canonical"> and og:url equal to
# its canonical URL; with the page cache on, a second request is a hit with
# the same status, body and headers; every wikilink in the page routes to a
# rewrite, or names a fallback page's file path. Then the sitemap's <loc>
# list is compared with the index. A full crawl renders about 2,500 pages
# and takes several minutes.
#
# --timing renders no page and prints the cost of the routing layer and the
# page cache in milliseconds, each the best of seven repeats. Exits 1 when a
# per-request figure is over its limit.
require 'erb'
require 'cgi'
require 'benchmark'
require 'rack/mock'
require 'gollum/app'

config, wiki, mode = ARGV
abort 'Usage: ruby tools/check_urls.rb <config.rb> <wiki> [--crawl | --timing]' unless config && wiki
Precious::App.set(:environment, :production)
Precious::App.set(:gollum_path, wiki)
Precious::App.set(:wiki_options, {})
load config
Precious::App.set(:wiki_options, Precious::App.settings.wiki_options.merge(template_dir: File.join(wiki, '.gollum/templates')))
$stdout.sync = true

site = GnollHackCrawlerSupport::SITE_URL
index = GnollHackPageIndexCache.current
abort 'The page index could not be built.' unless index
failed = false

index.pages.sort.each { |page| puts "#{page}\t#{site}#{index.canonical_path(page)}" }
puts "pages: #{index.pages.length}"
puts "fallbacks: #{index.fallbacks.length}"
index.fallbacks.sort.each { |page, reason| puts "  #{page}\t#{reason}" }
index.collisions.sort.each { |slug, group| puts "  collision #{slug}: #{group.join(', ')}" }
failed = true unless index.fallbacks.empty?

home_link = Gollum::Wiki.new(wiki, Precious::App.settings.wiki_options).preview_page('Test', '[[Home]]', :markdown).formatted_data
if home_link.include?('href="/"')
  puts 'OK   [[Home]] renders href="/"'
else
  puts "FAIL [[Home]] renders #{home_link[/<a [^>]*>/].inspect}"
  failed = true
end

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

def best_of_seven(count)
  Array.new(7) { Benchmark.realtime { count.times { yield } } / count * 1000 }.min
end

case mode
when '--crawl'
  checks = Checks.new
  req = Rack::MockRequest.new(Precious::App)
  router = GnollHackUrls::Router.new(index)
  store = GnollHackRenderedPages
  canonical_tag = %r{<link rel="canonical" href="([^"]*)" />}
  og_url = /<meta property="og:url" content="([^"]*)"/
  pages = index.pages.sort
  pages.each_with_index do |page, i|
    canonical = index.canonical_path(page)
    escaped = "/#{GnollHackUrls.escape_path(page)}"
    if index.slug_for(page)
      decoded = Rack::Utils.unescape_path(canonical)
      olds = [escaped, escaped.sub(/\.[^.\/]+\z/, ''), canonical.downcase].uniq
      olds.reject { |old| Rack::Utils.unescape_path(old) == decoded }.each do |old|
        res = req.get(old)
        checks.check('old URL answers 301 to the canonical path', res.status == 301 && res.headers['location'] == canonical,
                     "#{old} -> #{res.status} #{res.headers['location']}")
      end
    end

    res = req.get(canonical)
    body = res.body.to_s.dup.force_encoding('UTF-8')
    want = "#{site}#{canonical}"
    checks.check('canonical path answers 200', res.status == 200, "#{canonical} -> #{res.status}")
    checks.check('canonical tag and og:url', CGI.unescapeHTML(body[canonical_tag, 1].to_s) == want && CGI.unescapeHTML(body[og_url, 1].to_s) == want,
                 "#{canonical}: #{body[canonical_tag, 1].inspect} #{body[og_url, 1].inspect}")
    if store && index.slug_for(page)
      again = req.get(canonical)
      headers = ->(r) { r.headers.to_h.reject { |k, _| k == 'x-gnollhack-cache' } }
      checks.check('first request is a miss, second a hit with the same response',
                   res.headers['x-gnollhack-cache'] == 'miss' && again.headers['x-gnollhack-cache'] == 'hit' &&
                     again.status == res.status && again.body == res.body && headers.call(again) == headers.call(res),
                   "#{canonical}: #{res.headers['x-gnollhack-cache'].inspect}, #{again.headers['x-gnollhack-cache'].inspect}")
    end

    body.scan(/<a class="internal present" href="([^"]*)"/).each do |(href)|
      path, query = CGI.unescapeHTML(href).sub(/#.*\z/, '').split('?', 2)
      path = '/' if path.empty?
      action, = router.route(path, query)
      to_fallback = index.fallbacks.key?(Rack::Utils.unescape_path(path).delete_prefix('/'))
      checks.check('wikilinks route to a page', action == :rewrite || to_fallback, "#{page}: #{href} -> #{action}")
    end
    puts "  #{i + 1} of #{pages.length}" if ((i + 1) % 250).zero?
  end

  sitemap = req.get('/sitemap.xml').body.to_s.dup.force_encoding('UTF-8')
  locs = sitemap.scan(%r{<loc>([^<]*)</loc>}).flatten.map { |loc| CGI.unescapeHTML(loc) }
  listed = index.pages.reject { |page| page == 'README.md' }
  home = listed.include?('Home.md') ? ['Home.md'] : []
  want = (home + (listed - home)).map { |page| "#{site}#{index.canonical_path(page)}" }
  checks.check('sitemap lists the canonical URLs, Home first', locs.first == want.first && locs.sort == want.sort,
               "first #{locs.first.inspect}; #{(want - locs).length} missing, #{(locs - want).length} extra: #{((want - locs) + (locs - want)).first(5).inspect}")
  failed = true unless checks.report
when '--timing'
  noop = ->(_env) { [200, {}, []] }
  layer = GnollHackCleanUrls.new(noop)
  asset_env = Rack::MockRequest.env_for('/uploads/x.webp')
  page = index.pages.sort.find { |p| index.slug_for(p) && !index.slug_for(p).empty? }
  page_path = index.canonical_path(page)
  page_env = Rack::MockRequest.env_for(page_path)
  GnollHackPageIndexCache.snapshot
  figures = {}
  figures[:asset] = best_of_seven(50_000) { layer.call(asset_env) }
  GnollHackPageIndexCache.snapshot
  figures[:page] = best_of_seven(50_000) { layer.call(page_env) }
  # The due check and its reference are compared, so their repeats alternate
  # and a machine that slows down for a while affects both alike.
  ref = Gollum::Wiki.new(wiki, Precious::App.settings.wiki_options).ref
  pairs = Array.new(7) do
    due = Benchmark.realtime do
      300.times do
        GnollHackPageIndexCache.expire!
        GnollHackPageIndexCache.snapshot
      end
    end
    reference = Benchmark.realtime do
      300.times do
        repo = Rugged::Repository.new(wiki)
        repo.rev_parse(ref).oid
        repo.close
      end
    end
    [due / 300 * 1000, reference / 300 * 1000]
  end
  figures[:due_check] = pairs.map(&:first).min
  figures[:reference] = pairs.map(&:last).min
  figures[:rebuild] = best_of_seven(5) do
    GnollHackPageIndexCache.reset!
    GnollHackPageIndexCache.snapshot
  end
  if GnollHackRenderedPages
    Precious::App.call(page_env.dup)
    figures[:cached_page] = best_of_seven(2_000) do
      status, headers, = Precious::App.call(page_env.dup)
      raise "#{page_path} answered #{status} #{headers['x-gnollhack-cache'].inspect}" unless headers['x-gnollhack-cache'] == 'hit'
    end
    figures[:render] = best_of_seven(5) do
      GnollHackRenderedPages.clear
      Precious::App.call(page_env.dup)
    end
  end
  puts "page: #{page_path}"
  figures.each { |name, ms| puts format('%-12s %10.4f ms', name, ms) }
  gate = GnollHackPageIndexCache.gate
  puts "gate: #{gate}"

  limits = { asset: 0.05, page: 0.5, cached_page: 0.5 }
  limits.each do |name, limit|
    next unless figures[name] && figures[name] > limit
    puts "FAIL #{name} #{figures[name].round(4)} ms is over #{limit} ms"
    failed = true
  end
  if gate == :stat && figures[:due_check] > figures[:reference] / 2
    puts "FAIL due check #{figures[:due_check].round(4)} ms is over half the reference #{figures[:reference].round(4)} ms"
    failed = true
  end
when nil
  nil
else
  abort "Unknown option #{mode}"
end

exit(failed ? 1 : 0)
