require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'gnollhack_assets'
require 'gnollhack_http_caching'

# Tests of the Cache-Control policy in GnollHackHttpCaching.
class TestGnollHackHttpCaching < Minitest::Test
  IMMUTABLE = 'public, max-age=31536000, immutable'
  ONE_WEEK = 'public, max-age=604800'
  UPLOAD = 'public, max-age=86400, s-maxage=604800'
  DIGEST = 'e224' + ('0' * 58) + '3e'
  HTML = { 'content-type' => 'text/html;charset=utf-8' }.freeze
  IMAGE = { 'Content-Type' => 'image/webp' }.freeze

  def setup
    @root = Dir.mktmpdir('gnollhack-http-caching')
    path = File.join(@root, '.gollum/css/x.css')
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, 'body{color:black}')
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def policy(path, status: 200, headers: IMAGE, query: '')
    GnollHackHttpCaching.cache_control(@root, path, query, status, headers)
  end

  # Row 1: /.gollum/

  def test_theme_file_uses_the_asset_rules
    url = GnollHackAssets.versioned_url(@root, '/.gollum/css/x.css')
    version = url[/\?v=(.*)\z/, 1]
    assert_equal [IMMUTABLE, true], policy('/.gollum/css/x.css', query: "v=#{version}", headers: {})
    assert_equal ['no-cache', true], policy('/.gollum/css/x.css', query: 'v=0', headers: {})
    assert_equal ['no-cache', true], policy('/.gollum/css/x.css', headers: {})
    assert_equal [ONE_WEEK, true], policy('/.gollum/fonts/f.woff2', headers: {})
  end

  def test_templates_are_not_a_static_path
    assert_equal ['no-cache', false], policy('/.gollum/templates/layout.mustache', headers: {})
  end

  # Rows 2 to 4: /gollum/assets/

  def test_sprockets_digest_is_immutable
    assert_equal [IMMUTABLE, true], policy("/gollum/assets/app-#{DIGEST}.css")
    assert_equal [IMMUTABLE, true], policy("/gollum/assets/app-#{DIGEST}.js")
  end

  def test_undigested_stylesheet_and_script_are_revalidated
    assert_equal ['no-cache', true], policy('/gollum/assets/app.css')
    assert_equal ['no-cache', true], policy('/gollum/assets/editor.js')
  end

  def test_other_gollum_assets_are_cached_for_a_week
    assert_equal [ONE_WEEK, true], policy('/gollum/assets/katex/fonts/KaTeX_Main-Regular.woff2')
  end

  # Row 5: uploads and other static files

  def test_upload_is_cached_a_day_in_browsers_and_a_week_at_the_edge
    assert_equal [UPLOAD, true], policy('/uploads/Guides/A%20B/x-q85.webp')
  end

  def test_extension_is_compared_without_case
    assert_equal [UPLOAD, true], policy('/uploads/X.WEBP')
  end

  def test_favicon_is_a_static_file
    assert_equal [UPLOAD, true], policy('/favicon.ico', headers: { 'content-type' => 'image/vnd.microsoft.icon' })
  end

  def test_static_extension_answered_as_html_is_a_page
    assert_equal ['no-cache', false], policy('/Foo.png', headers: HTML)
  end

  def test_partial_and_not_modified_are_served
    assert_equal [UPLOAD, true], policy('/uploads/x.webp', status: 206)
    assert_equal [UPLOAD, true], policy('/uploads/x.webp', status: 304)
    assert_equal [IMMUTABLE, true], policy("/gollum/assets/app-#{DIGEST}.css", status: 304)
  end

  # Row 6: static paths not served

  def test_missing_static_file_is_revalidated_with_overwrite
    assert_equal ['no-cache', true], policy('/.gollum/css/missing.css', status: 404, headers: HTML)
    assert_equal ['no-cache', true], policy("/gollum/assets/app-#{DIGEST}.css", status: 404, headers: HTML)
    assert_equal ['no-cache', true], policy('/gollum/assets/app.css', status: 404, headers: HTML)
    assert_equal ['no-cache', true], policy('/gollum/assets/katex/fonts/x.woff2', status: 500, headers: HTML)
    assert_equal ['no-cache', true], policy('/uploads/does-not-exist.webp', status: 404, headers: HTML)
  end

  # Row 7: everything else

  def test_page_gets_no_cache_without_overwrite
    assert_equal ['no-cache', false], policy('/Guides/Some_Page', headers: HTML)
    assert_equal ['no-cache', false], policy('/', headers: HTML)
    assert_equal ['no-cache', false], policy('/Missing_Page', status: 404, headers: HTML)
    assert_equal ['no-cache', false], policy('/gollum/history/Home.md', headers: HTML)
  end

  def test_redirect_keeps_its_cache_control
    value, overwrite = policy('/Home.md', status: 301, headers: HTML.merge('cache-control' => 'public, max-age=86400'))
    assert_equal 'no-cache', value
    refute overwrite
  end

  def test_undecodable_path_is_not_a_static_path
    assert_equal ['no-cache', false], policy('/uploads/%E0%A4%A.png')
  end

  def test_non_string_path_is_not_a_static_path
    assert_equal ['no-cache', false], policy(nil)
  end
end
