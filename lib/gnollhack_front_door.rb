# Requests that come through Azure Front Door: the check of the X-Azure-FDID
# header against the profile's ID, and the request environment pinned to the
# public site, so URLs built from the request never name the origin host.

require 'uri'

module GnollHackFrontDoor
  # The IDs in a GNOLLHACK_FRONT_DOOR_ID value: comma-separated, whitespace
  # stripped, lowercased, empty entries dropped. nil or blank gives [].
  def self.parse_ids(value)
    value.to_s.split(',').map { |id| id.strip.downcase }.reject(&:empty?)
  end

  # True when ids is empty (the check is off) or the request's X-Azure-FDID,
  # lowercased and stripped, is one of them.
  def self.allowed?(env, ids)
    ids.empty? || ids.include?(env['HTTP_X_AZURE_FDID'].to_s.strip.downcase)
  end

  # The env a request that came through Front Door is served with: the host
  # headers and SERVER_NAME set to the site's host, the scheme to https on
  # port 443, and the Forwarded and X-Forwarded-Port headers removed. A
  # request without an X-Azure-FDID header is returned unchanged. Returns a
  # new hash; the argument is not modified.
  def self.pin_public_host(env, site_url)
    return env unless env.key?('HTTP_X_AZURE_FDID')
    host = URI(site_url).host
    pinned = env.merge(
      'HTTP_HOST' => host,
      'HTTP_X_FORWARDED_HOST' => host,
      'SERVER_NAME' => host,
      'HTTP_X_FORWARDED_PROTO' => 'https',
      'rack.url_scheme' => 'https',
      'SERVER_PORT' => '443'
    )
    pinned.delete('HTTP_FORWARDED')
    pinned.delete('HTTP_X_FORWARDED_PORT')
    pinned
  end

  # A Location header for a request that came through Front Door: a path
  # (starting with one /) is joined to site_url; anything else is returned
  # unchanged. WEBrick makes a path Location absolute from the request's own
  # Host and X-Forwarded-Host, outside the application.
  def self.public_location(location, site_url)
    return location unless location.is_a?(String) && location.start_with?('/') && !location.start_with?('//')
    "#{site_url.chomp('/')}#{location}"
  end
end
