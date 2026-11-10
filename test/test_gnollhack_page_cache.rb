require 'minitest/autorun'
require 'timeout'
require 'gnollhack_page_cache'

# Tests of the in-memory store of rendered page responses in GnollHackPageCache.
class TestGnollHackPageCache < Minitest::Test
  # A body that records how it was read.
  class Body
    attr_reader :closed

    def initialize(*parts)
      @parts = parts
      @closed = 0
      @read = false
    end

    def each(&block)
      @read = true
      @parts.each(&block)
    end

    def close
      @closed += 1
    end

    def read?
      @read
    end
  end

  def setup
    @store = GnollHackPageCache::Store.new(max_bytes: 1_000_000)
    @renders = 0
  end

  def page(text, status: 200, type: 'text/html;charset=utf-8', extra: {})
    [status, { 'content-type' => type, 'content-length' => text.bytesize.to_s }.merge(extra), [text]]
  end

  def fetch(key, epoch: 1, store: @store, response: nil, text: "<p>#{key}</p>")
    store.fetch(epoch, key) do
      @renders += 1
      response || page(text)
    end
  end

  def body_of(response)
    text = +''
    response[2].each { |part| text << part }
    text
  end

  def test_miss_then_hit
    first = fetch('/A.md')
    second = fetch('/A.md')
    assert_equal 1, @renders
    assert_equal 'miss', first[1]['x-gnollhack-cache']
    assert_equal 'hit', second[1]['x-gnollhack-cache']
    assert_equal body_of(first), body_of(second)
    assert_equal '<p>/A.md</p>', body_of(second)
    assert_equal 'text/html;charset=utf-8', second[1]['content-type']
    assert_equal '12', second[1]['content-length']
    stored = second[2].first
    assert stored.frozen?
    assert_equal Encoding::BINARY, stored.encoding
  end

  def test_body_parts_are_joined_and_closed
    body = Body.new('<p>', 'one', '</p>')
    response = fetch('/A.md', response: [200, { 'content-type' => 'text/html' }, body])
    assert_equal '<p>one</p>', body_of(response)
    assert_equal 1, body.closed
    assert_equal '<p>one</p>', body_of(fetch('/A.md'))
  end

  def test_responses_that_are_not_pages_are_not_stored
    responses = [
      page('x', status: 404), page('x', status: 301), page('x', status: 500),
      page('x', type: 'text/markdown'), page('x', type: 'application/json'),
      page('x', extra: { 'set-cookie' => 'a=b' }),
      page('x', extra: { 'cache-control' => 'private' }), page('x', extra: { 'cache-control' => 'no-store' })
    ]
    responses.each_with_index do |(status, headers, _), i|
      body = Body.new('x')
      original = [status, headers, body]
      result = fetch("/P#{i}.md", response: original)
      assert_same original, result
      assert_nil result[1]['x-gnollhack-cache']
      refute body.read?
      assert_equal 0, body.closed
    end
    assert_equal 0, @store.stats[:entries]
  end

  def test_newer_epoch_empties_the_store
    fetch('/A.md', epoch: 1)
    response = fetch('/A.md', epoch: 2)
    assert_equal 'miss', response[1]['x-gnollhack-cache']
    assert_equal 2, @renders
    assert_equal 1, @store.stats[:clears]
    assert_equal 2, @store.stats[:epoch]
  end

  def test_older_epoch_gets_its_own_render
    fetch('/A.md', epoch: 2)
    entries = @store.stats[:entries]
    original = page('old')
    result = fetch('/A.md', epoch: 1, response: original)
    assert_same original, result
    assert_equal entries, @store.stats[:entries]
    assert_equal 'hit', fetch('/A.md', epoch: 2)[1]['x-gnollhack-cache']
  end

  def test_overtaken_render_is_returned_but_not_stored
    result = @store.fetch(1, '/A.md') do
      fetch('/B.md', epoch: 2)
      page('<p>old</p>')
    end
    assert_equal 'miss', result[1]['x-gnollhack-cache']
    assert_equal '<p>old</p>', body_of(result)
    assert_equal 1, @store.stats[:not_stored]
    assert_equal 'miss', fetch('/A.md', epoch: 2)[1]['x-gnollhack-cache']
  end

  def test_least_recently_used_entries_are_evicted
    store = GnollHackPageCache::Store.new(max_bytes: 100)
    text = 'x' * 40
    %w[/A /B /C].each { |key| fetch(key, store: store, text: text) }
    assert_equal 2, store.stats[:entries]
    assert_equal 80, store.stats[:bytes]
    assert_equal 1, store.stats[:evictions]
    assert_equal 'miss', fetch('/A', store: store, text: text)[1]['x-gnollhack-cache']

    store = GnollHackPageCache::Store.new(max_bytes: 100)
    fetch('/A', store: store, text: text)
    fetch('/B', store: store, text: text)
    fetch('/A', store: store, text: text)
    fetch('/C', store: store, text: text)
    assert_equal 'hit', fetch('/A', store: store, text: text)[1]['x-gnollhack-cache']
    assert_equal 'hit', fetch('/C', store: store, text: text)[1]['x-gnollhack-cache']
    assert_equal 'miss', fetch('/B', store: store, text: text)[1]['x-gnollhack-cache']
    assert_equal 80, store.stats[:bytes]
  end

  def test_body_larger_than_the_limit_is_not_stored
    store = GnollHackPageCache::Store.new(max_bytes: 100)
    fetch('/A', store: store, text: 'x' * 40)
    response = fetch('/Big', store: store, text: 'y' * 200)
    assert_equal 'y' * 200, body_of(response)
    assert_equal 'miss', response[1]['x-gnollhack-cache']
    assert_equal 1, store.stats[:entries]
    assert_equal 40, store.stats[:bytes]
    assert_equal 1, store.stats[:not_stored]
  end

  def test_one_render_per_key_at_a_time
    gate = Queue.new
    renders = 0
    count_lock = Mutex.new
    threads = Array.new(4) do
      Thread.new do
        @store.fetch(1, '/A.md') do
          count_lock.synchronize { renders += 1 }
          gate.pop
          page('<p>shared</p>')
        end
      end
    end
    sleep 0.2
    gate << true
    gate << true
    results = Timeout.timeout(5) { threads.map(&:value) }
    assert_equal 1, renders
    assert_equal %w[hit hit hit miss], results.map { |r| r[1]['x-gnollhack-cache'] }.sort
    assert_equal ['<p>shared</p>'], results.map { |r| body_of(r) }.uniq
  end

  def test_different_keys_render_at_the_same_time
    started = Queue.new
    release = Queue.new
    threads = %w[/A.md /B.md].map do |key|
      Thread.new do
        @store.fetch(1, key) do
          started << key
          release.pop
          page("<p>#{key}</p>")
        end
      end
    end
    Timeout.timeout(5) { 2.times { started.pop } }
    2.times { release << true }
    results = Timeout.timeout(5) { threads.map(&:value) }
    assert_equal %w[miss miss], results.map { |r| r[1]['x-gnollhack-cache'] }
  end

  def test_block_that_raises_leaves_no_lock_behind
    assert_raises(RuntimeError) { @store.fetch(1, '/A.md') { raise 'render failed' } }
    response = Timeout.timeout(5) { fetch('/A.md') }
    assert_equal 'miss', response[1]['x-gnollhack-cache']
  end

  def test_clear_keeps_the_epoch
    fetch('/A.md', epoch: 3)
    @store.clear
    assert_equal 0, @store.stats[:entries]
    assert_equal 3, @store.stats[:epoch]
    assert_equal 'miss', fetch('/A.md', epoch: 3)[1]['x-gnollhack-cache']
  end
end
