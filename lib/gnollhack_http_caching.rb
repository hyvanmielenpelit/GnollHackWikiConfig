# The Cache-Control header of every response the wiki serves: long-lived for
# versioned and fingerprinted files, shorter for fonts, images and uploads,
# and no-cache for pages and everything else, so a CDN caches files and
# never pages.

require 'rack/utils'
require_relative 'gnollhack_assets'

module GnollHackHttpCaching
  GOLLUM_ASSETS_PREFIX = '/gollum/assets/'
  GOLLUM_PREFIX = '/gollum/'

  # One day in browsers, one week at the edge. An upload replaced under the
  # same name is purged from the CDN by hand.
  UPLOAD = 'public, max-age=86400, s-maxage=604800'

  # Sprockets fingerprint: app-<sha256>.css.
  SPROCKETS_DIGEST = /-[0-9a-f]{64}\.[A-Za-z0-9]+\z/

  # Files outside /gollum/ that are cached like uploads, by the extension of
  # the decoded last segment.
  STATIC_EXTENSIONS = %w[.webp .png .jpg .jpeg .gif .svg .ico .avif .pdf .woff .woff2].freeze

  SERVED_STATUSES = [200, 206, 304].freeze

  # Returns [value, overwrite]: the Cache-Control value, and whether it
  # replaces a Cache-Control the response already has. path is the request's
  # PATH_INFO as the client sent it, before any slug rewrite.
  def self.cache_control(wiki_root, path, query_string, status, headers)
    decoded = decode(path)
    return [GnollHackAssets::REVALIDATE, false] unless decoded

    served = SERVED_STATUSES.include?(status.to_i)
    file_policy = file_policy(wiki_root, path, query_string, decoded, headers)
    if file_policy
      [served ? file_policy : GnollHackAssets::REVALIDATE, true]
    elsif !served && static_path?(decoded)
      [GnollHackAssets::REVALIDATE, true]
    else
      [GnollHackAssets::REVALIDATE, false]
    end
  end

  # The value for a served file under one of the static paths, or nil when
  # the path is not one of them.
  def self.file_policy(wiki_root, path, query_string, decoded, headers)
    if decoded.start_with?(GnollHackAssets::PREFIX) && !decoded.start_with?(GnollHackAssets::TEMPLATES_PREFIX)
      GnollHackAssets.cache_control(wiki_root, path, query_string) || GnollHackAssets::REVALIDATE
    elsif decoded.start_with?(GOLLUM_ASSETS_PREFIX)
      name = last_segment(decoded)
      if name.match?(SPROCKETS_DIGEST)
        GnollHackAssets::IMMUTABLE
      elsif GnollHackAssets::REVALIDATED_EXTENSIONS.include?(File.extname(name).downcase)
        GnollHackAssets::REVALIDATE
      else
        GnollHackAssets::ONE_WEEK
      end
    elsif static_path?(decoded) && !header(headers, 'content-type').to_s.start_with?('text/html')
      UPLOAD
    end
  end

  # A path outside /gollum/ whose last segment has a static file extension.
  def self.static_path?(decoded)
    !decoded.start_with?(GOLLUM_PREFIX) && STATIC_EXTENSIONS.include?(File.extname(last_segment(decoded)).downcase)
  end

  def self.last_segment(decoded)
    decoded.split('/').last.to_s
  end

  # The URL-decoded path, or nil when it is not a string or does not decode
  # to valid UTF-8.
  def self.decode(path)
    return nil unless path.is_a?(String)
    decoded = Rack::Utils.unescape_path(path).dup.force_encoding(Encoding::UTF_8)
    decoded.valid_encoding? ? decoded : nil
  rescue ArgumentError
    nil
  end

  def self.header(headers, name)
    headers.each { |key, value| return value if key.to_s.casecmp?(name) }
    nil
  end

  private_class_method :file_policy, :static_path?, :last_segment, :decode, :header
end
