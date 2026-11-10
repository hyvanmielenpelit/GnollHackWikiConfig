require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'digest'
require 'gnollhack_assets'

# Tests of the content-hash URLs and Cache-Control headers in GnollHackAssets.
class TestGnollHackAssets < Minitest::Test
  CSS_URL = '/.gollum/css/x.css'
  FONT_URL = '/.gollum/fonts/f.woff2'

  def setup
    @root = Dir.mktmpdir('gnollhack-assets')
    write('.gollum/css/x.css', 'body{color:black}')
    write('.gollum/fonts/f.woff2', 'font-bytes')
    write('config.rb', '# config')
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def write(relative, content)
    path = File.join(@root, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, content)
    path
  end

  def version_of(url)
    url[/\?v=(.*)\z/, 1]
  end

  # versioned_url

  def test_versioned_url_appends_sixteen_hex_digits
    url = GnollHackAssets.versioned_url(@root, CSS_URL)
    assert_match(/\A#{Regexp.escape(CSS_URL)}\?v=[0-9a-f]{16}\z/, url)
    assert_equal Digest::SHA256.hexdigest('body{color:black}')[0, 16], version_of(url)
  end

  def test_versioned_url_changes_with_content_at_same_mtime
    path = File.join(@root, '.gollum/css/x.css')
    before = GnollHackAssets.versioned_url(@root, CSS_URL)
    mtime = File.mtime(path)
    File.binwrite(path, 'body{color:red;background:white}')
    File.utime(mtime, mtime, path)
    after = GnollHackAssets.versioned_url(@root, CSS_URL)
    refute_equal before, after
    assert_equal Digest::SHA256.hexdigest('body{color:red;background:white}')[0, 16], version_of(after)
  end

  def test_versioned_url_of_missing_file_is_plain
    assert_equal '/.gollum/css/missing.css', GnollHackAssets.versioned_url(@root, '/.gollum/css/missing.css')
  end

  def test_versioned_url_outside_gollum_folder_is_plain
    assert_equal '/.gollum/../config.rb', GnollHackAssets.versioned_url(@root, '/.gollum/../config.rb')
    assert_equal '/etc/x', GnollHackAssets.versioned_url(@root, '/etc/x')
  end

  # cache_control

  def test_current_version_is_immutable
    version = version_of(GnollHackAssets.versioned_url(@root, CSS_URL))
    assert_equal 'public, max-age=31536000, immutable',
                 GnollHackAssets.cache_control(@root, CSS_URL, "v=#{version}")
  end

  def test_other_version_is_revalidated
    assert_equal 'no-cache', GnollHackAssets.cache_control(@root, CSS_URL, 'v=0000000000000000')
  end

  def test_unversioned_stylesheet_and_script_are_revalidated
    assert_equal 'no-cache', GnollHackAssets.cache_control(@root, CSS_URL, '')
    assert_equal 'no-cache', GnollHackAssets.cache_control(@root, '/.gollum/js/app.js', nil)
  end

  def test_unversioned_font_and_image_are_cached_for_a_week
    assert_equal 'public, max-age=604800', GnollHackAssets.cache_control(@root, FONT_URL, '')
    assert_equal 'public, max-age=604800', GnollHackAssets.cache_control(@root, '/.gollum/images/logo.png', nil)
  end

  def test_templates_are_left_alone
    assert_nil GnollHackAssets.cache_control(@root, '/.gollum/templates/layout.mustache', '')
  end

  def test_paths_outside_gollum_folder_are_left_alone
    assert_nil GnollHackAssets.cache_control(@root, '/Home', '')
  end

  # outdated_urls. The count and the files versioned_url was asked about
  # outlive a test, so each case settles the count first and asserts on the
  # difference.

  def settled_outdated_count
    GnollHackAssets.outdated_urls
  end

  def rewrite(relative, content)
    path = File.join(@root, relative)
    File.binwrite(path, content)
    later = File.mtime(path) + 5
    File.utime(later, later, path)
  end

  def test_unchanged_file_is_not_outdated
    GnollHackAssets.versioned_url(@root, CSS_URL)
    base = settled_outdated_count
    GnollHackAssets.versioned_url(@root, CSS_URL)
    assert_equal base, GnollHackAssets.outdated_urls
  end

  def test_changed_file_is_outdated_once
    GnollHackAssets.versioned_url(@root, CSS_URL)
    base = settled_outdated_count
    rewrite('.gollum/css/x.css', 'body{color:red;margin:0}')
    assert_equal base + 1, GnollHackAssets.outdated_urls
    assert_equal base + 1, GnollHackAssets.outdated_urls
  end

  def test_change_seen_first_by_a_render_is_counted
    GnollHackAssets.versioned_url(@root, CSS_URL)
    base = settled_outdated_count
    rewrite('.gollum/css/x.css', 'body{color:blue;margin:1px}')
    GnollHackAssets.versioned_url(@root, CSS_URL)
    assert_equal base + 1, GnollHackAssets.outdated_urls
  end

  def test_deleted_file_is_outdated_once
    GnollHackAssets.versioned_url(@root, CSS_URL)
    base = settled_outdated_count
    File.delete(File.join(@root, '.gollum/css/x.css'))
    assert_equal base + 1, GnollHackAssets.outdated_urls
    assert_equal base + 1, GnollHackAssets.outdated_urls
  end

  def test_file_only_cache_control_saw_is_not_tracked
    version = Digest::SHA256.hexdigest('font-bytes')[0, 16]
    GnollHackAssets.cache_control(@root, FONT_URL, "v=#{version}")
    base = settled_outdated_count
    rewrite('.gollum/fonts/f.woff2', 'other-font-bytes')
    assert_equal base, GnollHackAssets.outdated_urls
  end

  def test_path_outside_gollum_folder_is_not_tracked
    GnollHackAssets.versioned_url(@root, '/.gollum/../config.rb')
    base = settled_outdated_count
    rewrite('config.rb', '# another config')
    assert_equal base, GnollHackAssets.outdated_urls
  end
end
