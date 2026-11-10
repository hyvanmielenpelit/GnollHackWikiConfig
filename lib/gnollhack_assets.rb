# Content-hash URLs and Cache-Control headers for the files Gollum serves
# from a wiki's .gollum folder, such as the theme stylesheet and its fonts.

require 'digest'
require 'rack/utils'

module GnollHackAssets
  PREFIX = '/.gollum/'
  TEMPLATES_PREFIX = '/.gollum/templates/'
  DIGEST_LENGTH = 16

  IMMUTABLE = 'public, max-age=31536000, immutable'
  REVALIDATE = 'no-cache'
  ONE_WEEK = 'public, max-age=604800'

  # Unversioned files of these types are revalidated on every use. Fonts and
  # images take a new file name when their content changes, so they can be
  # cached for a week.
  REVALIDATED_EXTENSIONS = %w[.css .js].freeze

  # Absolute file path => [mtime, size, digest]; a file is hashed again when
  # its mtime or size changes.
  @digests = {}
  # Absolute file path => the digest versioned_url last returned for it, or
  # nil when the file could not be read.
  @issued = {}
  # How many times a digest in @issued has been replaced by a different one.
  @outdated = 0
  @lock = Mutex.new

  # Root-relative URL under /.gollum/ with ?v=<first 16 hex of the SHA-256 of
  # the file>. A file that does not exist, or a path outside the wiki's
  # .gollum folder, keeps its plain URL.
  def self.versioned_url(wiki_root, url_path)
    path = file_path(wiki_root, url_path)
    digest = path ? file_digest(path) : nil
    note_issue(path, digest) if path
    digest ? "#{url_path}?v=#{digest}" : url_path
  end

  # How many times a versioned URL that versioned_url returned has gone out
  # of date, because its file changed or disappeared. Each file that
  # versioned_url has been asked about is checked again here; the count only
  # grows.
  def self.outdated_urls
    paths = @lock.synchronize { @issued.keys }
    paths.each { |path| note_issue(path, file_digest(path)) }
    @lock.synchronize { @outdated }
  end

  # Cache-Control for a GET of a /.gollum/ file, or nil to leave the response
  # as is. Only a v that equals the current digest is cached as immutable, so
  # an old URL never pins new content.
  def self.cache_control(wiki_root, url_path, query_string)
    return nil unless url_path.to_s.start_with?(PREFIX) && !url_path.start_with?(TEMPLATES_PREFIX)
    version = Array(Rack::Utils.parse_query(query_string.to_s)['v']).last
    if version
      version == digest(wiki_root, url_path) ? IMMUTABLE : REVALIDATE
    elsif REVALIDATED_EXTENSIONS.include?(File.extname(url_path).downcase)
      REVALIDATE
    else
      ONE_WEEK
    end
  end

  # The digest of the file a URL path names, or nil.
  def self.digest(wiki_root, url_path)
    path = file_path(wiki_root, url_path)
    path ? file_digest(path) : nil
  end

  # The digest of the file at an absolute path, or nil when it is not a
  # readable file.
  def self.file_digest(path)
    stat = File.stat(path)
    return nil unless stat.file?
    @lock.synchronize do
      mtime, size, digest = @digests[path]
      return digest if mtime == stat.mtime && size == stat.size
    end
    digest = Digest::SHA256.file(path).hexdigest[0, DIGEST_LENGTH]
    @lock.synchronize { @digests[path] = [stat.mtime, stat.size, digest] }
    digest
  rescue SystemCallError, ArgumentError
    nil
  end

  # Records the digest versioned_url returned for a file, counting a change
  # from the one recorded before. The first digest for a file does not count.
  def self.note_issue(path, digest)
    @lock.synchronize do
      @outdated += 1 if @issued.key?(path) && @issued[path] != digest
      @issued[path] = digest
    end
  end

  # The absolute path a /.gollum/ URL path names, or nil when it is not under
  # the wiki's .gollum folder.
  def self.file_path(wiki_root, url_path)
    return nil unless url_path.is_a?(String) && url_path.start_with?(PREFIX)
    folder = File.expand_path('.gollum', wiki_root)
    path = File.expand_path(Rack::Utils.unescape_path(url_path).delete_prefix('/'), wiki_root)
    path.start_with?("#{folder}/") ? path : nil
  rescue ArgumentError
    nil
  end

  private_class_method :digest, :file_digest, :note_issue, :file_path
end
