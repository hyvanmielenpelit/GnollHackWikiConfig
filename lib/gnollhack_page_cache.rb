# An in-memory store of whole rendered page responses (Rack triplets with
# lowercase header names), all belonging to one epoch: a number that grows
# whenever anything a page is rendered from changes. A newer epoch empties
# the store; nothing is invalidated selectively or expired by time.

module GnollHackPageCache
  HEADER = 'x-gnollhack-cache'

  class Store
    def initialize(max_bytes:)
      @max_bytes = max_bytes
      @lock = Mutex.new
      @epoch = 0
      # key => [headers, body], least recently used first.
      @entries = {}
      @bytes = 0
      # key => [render Mutex, number of requests holding or waiting for it]
      @rendering = {}
      @counts = Hash.new(0)
    end

    # The stored response for key at epoch, or the block's response, which is
    # stored when it is a page and epoch is still the store's epoch once the
    # block has returned. Requests for one key render one at a time.
    def fetch(epoch, key)
      entry = @lock.synchronize do
        if epoch > @epoch
          @counts[:clears] += 1 unless @entries.empty?
          @entries = {}
          @bytes = 0
          @epoch = epoch
        end
        epoch == @epoch ? touch(key) : nil
      end
      return respond(entry, 'hit') if entry
      return yield if epoch < @lock.synchronize { @epoch }

      render_lock = @lock.synchronize do
        slot = (@rendering[key] ||= [Mutex.new, 0])
        slot[1] += 1
        slot[0]
      end
      begin
        render_lock.synchronize do
          entry = @lock.synchronize { epoch == @epoch ? touch(key) : nil }
          next respond(entry, 'hit') if entry
          render(epoch, key) { yield }
        end
      ensure
        @lock.synchronize do
          slot = @rendering[key]
          @rendering.delete(key) if slot && (slot[1] -= 1).zero?
        end
      end
    end

    def stats
      @lock.synchronize do
        { entries: @entries.length, bytes: @bytes, epoch: @epoch, hits: @counts[:hits],
          misses: @counts[:misses], clears: @counts[:clears], evictions: @counts[:evictions],
          not_stored: @counts[:not_stored] }
      end
    end

    # Drops every entry and keeps the epoch.
    def clear
      @lock.synchronize do
        @entries = {}
        @bytes = 0
      end
    end

    private

    # Called with @lock held: the entry for key, moved to the most recently
    # used end, or nil.
    def touch(key)
      entry = @entries.delete(key)
      return nil unless entry
      @entries[key] = entry
      @counts[:hits] += 1
      entry
    end

    def render(epoch, key)
      response = yield
      status, headers, body = response
      return response unless storable?(status, headers)

      text = String.new(encoding: Encoding::BINARY)
      body.each { |part| text << part.b }
      body.close if body.respond_to?(:close)
      entry = [headers.dup.freeze, text.freeze].freeze

      @lock.synchronize do
        @counts[:misses] += 1
        if epoch == @epoch && text.bytesize <= @max_bytes
          store(key, entry)
        else
          @counts[:not_stored] += 1
        end
      end
      respond(entry, 'miss')
    end

    def storable?(status, headers)
      return false unless status.to_i == 200 && header(headers, 'content-type').to_s.start_with?('text/html')
      return false if header(headers, 'set-cookie')
      cache_control = header(headers, 'cache-control').to_s
      !cache_control.include?('private') && !cache_control.include?('no-store')
    end

    def header(headers, name)
      headers.each { |key, value| return value if key.to_s.casecmp?(name) }
      nil
    end

    # Called with @lock held.
    def store(key, entry)
      old = @entries.delete(key)
      @bytes -= old[1].bytesize if old
      @entries[key] = entry
      @bytes += entry[1].bytesize
      while @bytes > @max_bytes
        _, evicted = @entries.shift
        @bytes -= evicted[1].bytesize
        @counts[:evictions] += 1
      end
    end

    def respond(entry, state)
      headers, body = entry
      [200, headers.merge(HEADER => state), [body]]
    end
  end
end
