# Usage: ruby tools/check_cache.rb <config.rb> <throwaway wiki clone> <template folder copy>
#
# Tries to make the rendered page cache serve stale content, through
# Precious::App in-process: commits that edit, add and delete pages, the
# sidebar, repository maintenance, uncommitted template and stylesheet
# edits, a commit that lands during a render, simultaneous requests and a
# reset. Prints OK or FAIL per check and exits 1 on any failure.
#
# It commits to and resets the clone and edits the template copy, so it
# refuses to run (exit 2) unless the clone's origin is a local folder, its
# working tree is clean, and the template folder is outside it. The starting
# commit and the original template are restored at the end. Make the clone
# with git clone from a scratch clone and copy the template folder beside it,
# both outside every repository.
require 'erb'
require 'cgi'
require 'open3'
require 'rack/mock'
require 'gollum/app'

config, wiki, templates = ARGV
unless config && wiki && templates
  warn 'Usage: ruby tools/check_cache.rb <config.rb> <throwaway wiki clone> <template folder copy>'
  exit 2
end
wiki = File.expand_path(wiki)
templates = File.expand_path(templates)

def git_output(wiki, *args)
  out, status = Open3.capture2('git', '-C', wiki, *args)
  status.success? ? out.strip : nil
end

refusal =
  if (origin = git_output(wiki, 'remote', 'get-url', 'origin')).nil?
    'the clone has no origin'
  elsif !(File.directory?(origin) || origin.start_with?('file://'))
    "the clone's origin is not a local folder: #{origin}"
  elsif git_output(wiki, 'status', '--porcelain') != ''
    "the clone's working tree is not clean"
  elsif templates == wiki || templates.start_with?("#{wiki}/")
    'the template folder is inside the clone'
  elsif !File.file?(File.join(templates, 'layout.mustache'))
    'the template folder has no layout.mustache'
  end
if refusal
  warn "Refusing to run: #{refusal}."
  exit 2
end

Precious::App.set(:environment, :production)
Precious::App.set(:gollum_path, wiki)
Precious::App.set(:wiki_options, {})
load config
Precious::App.set(:wiki_options, Precious::App.settings.wiki_options.merge(template_dir: templates))
$stdout.sync = true

store = GnollHackRenderedPages
unless store
  warn 'The page cache is off (GNOLLHACK_PAGE_CACHE=0); there is nothing to check.'
  exit 2
end

# Counts renders, to tell a rendered answer from a cached one, and holds one
# render, after Gollum has rendered it, until it is released.
module GnollHackCacheProbe
  @renders = 0
  @hold = nil
  @held = Queue.new
  @release = Queue.new
  @lock = Mutex.new

  class << self
    attr_accessor :hold
    attr_reader :held, :release

    def renders
      @lock.synchronize { @renders }
    end

    def count
      @lock.synchronize { @renders += 1 }
    end
  end

  def show_page_or_file(fullpath)
    GnollHackCacheProbe.count
    result = super
    if GnollHackCacheProbe.hold && fullpath == GnollHackCacheProbe.hold
      GnollHackCacheProbe.hold = nil
      GnollHackCacheProbe.held << true
      GnollHackCacheProbe.release.pop
    end
    result
  end
end
Precious::App.prepend(GnollHackCacheProbe)

req = Rack::MockRequest.new(Precious::App)
index_cache = GnollHackPageIndexCache
start = git_output(wiki, 'rev-parse', 'HEAD')
layout = File.join(templates, 'layout.mustache')
layout_original = File.binread(layout)
failures = 0

check = lambda do |label, ok, detail = nil|
  failures += 1 unless ok
  puts format('%-4s %s%s', ok ? 'OK' : 'FAIL', label, ok || detail.nil? ? '' : "  [#{detail}]")
end
get = lambda do |url|
  res = req.get(url)
  [res, res.headers['x-gnollhack-cache'], res.body.to_s.dup.force_encoding('UTF-8')]
end
git = lambda do |*args|
  ok = system('git', '-C', wiki, '-c', 'user.name=Cache Check', '-c', 'user.email=cache-check@example.invalid',
              *args, out: File::NULL, err: File::NULL)
  raise "git #{args.join(' ')} failed" unless ok
end
settle = -> { sleep(index_cache::CHECK_INTERVAL + 0.15) }
write = ->(path, text) { File.binwrite(File.join(wiki, path), text) }
read = ->(path) { File.binread(File.join(wiki, path)).force_encoding('UTF-8') }
commit = lambda do |message|
  git.call('add', '-A')
  git.call('commit', '-q', '-m', message)
  settle.call
end
headers_of = ->(res) { res.headers.to_h.reject { |k, _| k == 'x-gnollhack-cache' } }

index = index_cache.current
abort 'The page index could not be built.' unless index
first_page, second_page = %w[Download.md Items/Battle-axe.md].map do |page|
  index.slug_for(page) ? page : index.pages.sort.find { |p| index.slug_for(p).to_s != '' }
end
second_page = index.pages.sort.find { |p| index.slug_for(p).to_s != '' && p != first_page } if second_page == first_page
first = index.canonical_path(first_page)
second = index.canonical_path(second_page)
first_file = "/#{GnollHackUrls.escape_path(first_page)}"
second_file = "/#{GnollHackUrls.escape_path(second_page)}"
puts "pages: #{first} (#{first_page}), #{second} (#{second_page})"

begin
  puts '--- 1. basics'
  r1, s1, b1 = get.call(first)
  r2, s2, b2 = get.call(first)
  check.call('first request is a miss, second a hit', s1 == 'miss' && s2 == 'hit', "#{s1.inspect}, #{s2.inspect}")
  check.call('the hit has the same body and headers', b1 == b2 && headers_of.call(r1) == headers_of.call(r2))
  store.clear
  _, s3, b3 = get.call(first)
  check.call('the cached body equals a fresh render', s3 == 'miss' && b3 == b1, s3.inspect)
  check.call('content-length equals the body size', r2.headers['content-length'].to_i == r2.body.bytesize,
             "#{r2.headers['content-length']} / #{r2.body.bytesize}")
  head = req.request('HEAD', first)
  check.call('HEAD answers 200 with an empty body', head.status == 200 && head.body.empty?, head.status)
  _, sq, bq = get.call("#{first}?foo=1")
  check.call('a query string is not cached', sq.nil? && bq == b1, sq.inspect)
  rraw, sraw, = get.call("#{first}?raw")
  check.call('?raw is not cached and returns Markdown', sraw.nil? && rraw.headers['content-type'].to_s.include?('markdown'),
             "#{sraw.inspect} #{rraw.headers['content-type']}")
  rold, sold, = get.call(first_file)
  check.call('the old .md URL answers 301, not cached', rold.status == 301 && rold.headers['location'] == first && sold.nil?,
             "#{rold.status} #{rold.headers['location']} #{sold.inspect}")
  ra, sa, = get.call('/no-such-cache-check-page')
  rb, sb, = get.call('/no-such-cache-check-page')
  check.call('an unknown slug answers 404 twice, not cached', ra.status == 404 && rb.status == 404 && sa.nil? && sb.nil?,
             "#{ra.status} #{rb.status}")
  renders = GnollHackCacheProbe.renders
  5.times { get.call(first) }
  check.call('five more requests render nothing', GnollHackCacheProbe.renders == renders,
             "#{GnollHackCacheProbe.renders - renders} renders")

  puts '--- 2. a commit that edits the page'
  write.call(first_page, "#{read.call(first_page)}\nCache check marker one.\n")
  commit.call('Edit the first page')
  _, s, b = get.call(first)
  check.call('the next request is a miss with the new text', s == 'miss' && b.include?('Cache check marker one.'), s.inspect)
  _, s, b = get.call(first)
  check.call('the one after is a hit with it', s == 'hit' && b.include?('Cache check marker one.'), s.inspect)

  puts '--- 3. a commit that edits the sidebar'
  get.call(second)
  write.call('_Sidebar.md', "#{read.call('_Sidebar.md')}\nCache check sidebar one.\n")
  commit.call('Edit the sidebar')
  _, s, b = get.call(first)
  check.call('a cached page is a miss with the new sidebar', s == 'miss' && b.include?('Cache check sidebar one.'), s.inspect)
  _, s, b = get.call(second)
  check.call('so is another cached page', s == 'miss' && b.include?('Cache check sidebar one.'), s.inspect)

  puts '--- 4. a commit that adds a page, then one that adds its link target'
  write.call('Cache Check Source.md', "See [[Cache Check Target]].\n")
  commit.call('Add a source page')
  _, _, b = get.call('/Cache_Check_Source')
  check.call('the link to the missing page is absent', b.include?('class="internal absent"'))
  get.call('/Cache_Check_Source')
  write.call('Cache Check Target.md', "Target.\n")
  commit.call('Add the target page')
  _, s, b = get.call('/Cache_Check_Source')
  check.call('the source is a miss whose link is present, with the slug',
             s == 'miss' && b.include?('<a class="internal present" href="/Cache_Check_Target">'), s.inspect)

  puts '--- 5. a commit that deletes a cached page'
  get.call('/Cache_Check_Target')
  get.call('/Cache_Check_Target')
  git.call('rm', '-q', 'Cache Check Target.md')
  git.call('commit', '-q', '-m', 'Delete the target page')
  settle.call
  r, s, = get.call('/Cache_Check_Target')
  check.call('its slug answers 404, not cached', r.status == 404 && s.nil?, "#{r.status} #{s.inspect}")
  _, _, b = get.call('/Cache_Check_Source')
  check.call('the link to it is absent again', b.include?('class="internal absent"'))

  puts '--- 6. pack-refs and gc'
  get.call(first)
  clears = store.stats[:clears]
  git.call('pack-refs', '--all')
  settle.call
  _, s_pack, = get.call(first)
  git.call('gc', '--quiet')
  settle.call
  _, s_gc, = get.call(first)
  check.call('a cached page stays a hit', s_pack == 'hit' && s_gc == 'hit' && store.stats[:clears] == clears,
             "#{s_pack.inspect}, #{s_gc.inspect}, clears +#{store.stats[:clears] - clears}")

  puts '--- 7. an uncommitted template edit'
  _, _, before = get.call(first)
  begin
    File.binwrite(layout, layout_original.sub('</head>', "<!-- cache-check-template-edit -->\n</head>"))
    settle.call
    _, s, b = get.call(first)
    check.call('the next request is a miss with the edit', s == 'miss' && b.include?('cache-check-template-edit'), s.inspect)
  ensure
    File.binwrite(layout, layout_original)
    settle.call
  end
  _, s, b = get.call(first)
  check.call('restoring it gives a miss equal to the body before', s == 'miss' && b == before, s.inspect)

  puts '--- 8. an uncommitted stylesheet edit'
  asset_url = before[%r{/\.gollum/[^"'?\s]+\?v=[0-9a-f]+}]
  if asset_url
    asset_path = Rack::Utils.unescape_path(asset_url[/\A[^?]+/]).delete_prefix('/')
    url_pattern = /#{Regexp.escape(asset_url[/\A[^?]+/])}\?v=[0-9a-f]+/
    asset_original = File.binread(File.join(wiki, asset_path))
    begin
      File.binwrite(File.join(wiki, asset_path), "#{asset_original}\n/* cache check */\n")
      settle.call
      _, s, b = get.call(first)
      check.call("the next request is a miss with a new ?v= for #{asset_path}", s == 'miss' && b[url_pattern] != asset_url,
                 "#{s.inspect} #{b[url_pattern]}")
    ensure
      File.binwrite(File.join(wiki, asset_path), asset_original)
      settle.call
    end
    _, _, b = get.call(first)
    check.call('restoring the file restores the URL', b[url_pattern] == asset_url, b[url_pattern])
  else
    check.call('the page has a versioned /.gollum/ URL', false)
  end

  puts '--- 9. a commit that lands during a render'
  store.clear
  not_stored = store.stats[:not_stored]
  GnollHackCacheProbe.hold = second_page
  held = Thread.new { get.call(second) }
  raise 'the held render never started' unless GnollHackCacheProbe.held.pop(timeout: 120)
  write.call('_Sidebar.md', "#{read.call('_Sidebar.md')}\nCache check sidebar two.\n")
  commit.call('Edit the sidebar again')
  _, s, b = get.call(first)
  check.call('another page is a miss with the new sidebar', s == 'miss' && b.include?('Cache check sidebar two.'), s.inspect)
  GnollHackCacheProbe.release << true
  _, s_held, b_held = held.value
  check.call('the held request returns the old sidebar with miss',
             s_held == 'miss' && !b_held.include?('Cache check sidebar two.'), s_held.inspect)
  check.call('and it was not stored', store.stats[:not_stored] == not_stored + 1,
             "not_stored +#{store.stats[:not_stored] - not_stored}")
  _, s, b = get.call(second)
  check.call('the next request for it is a miss with the new sidebar', s == 'miss' && b.include?('Cache check sidebar two.'),
             s.inspect)

  puts '--- 10. four simultaneous requests for one uncached page'
  store.clear
  renders = GnollHackCacheProbe.renders
  results = Array.new(4) { Thread.new { get.call(first) } }.map(&:value)
  states = results.map { |r| r[1] }.sort
  check.call('one render, one miss and three hits', GnollHackCacheProbe.renders == renders + 1 && states == %w[hit hit hit miss],
             "#{GnollHackCacheProbe.renders - renders} renders, #{states.inspect}")
  check.call('four equal bodies', results.map { |r| r[2] }.uniq.length == 1)

  puts '--- 11. a reset to the starting commit'
  git.call('reset', '-q', '--hard', start)
  settle.call
  _, s, b = get.call(first)
  check.call('the first page is a miss equal to the body from check 1', s == 'miss' && b == b1, s.inspect)
  r_source, = get.call('/Cache_Check_Source')
  check.call('pages added since answer 404', r_source.status == 404, r_source.status)

  puts "page cache: #{store.stats.inspect}; gate: #{index_cache.gate}"
ensure
  GnollHackCacheProbe.release << true
  File.binwrite(layout, layout_original) if File.binread(layout) != layout_original
  git.call('reset', '-q', '--hard', start)
  git.call('clean', '-q', '-fd')
end

puts failures.zero? ? 'ALL OK' : "#{failures} FAILED"
exit(failures.zero? ? 0 : 1)
