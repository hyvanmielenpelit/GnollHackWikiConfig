require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'gnollhack_urls'

# Tests of slug derivation, the page index, the request router, path
# classification and the file signature in GnollHackUrls.
class TestGnollHackUrls < Minitest::Test
  GUIDE = 'Guides/GnollHack, Gnoll Overseer, and GnollBench for Software Engineers.md'
  SHA = '0123456789abcdef0123456789abcdef01234567'

  def slug(path)
    GnollHackUrls.slug(path)
  end

  # Derivation

  def test_slug_of_example_page
    assert_equal 'guides/gnollhack-gnoll-overseer-and-gnollbench-for-software-engineers', slug(GUIDE)
  end

  def test_apostrophes_are_deleted
    assert_equal 'dungeon/wizards-tower', slug("Dungeon/Wizard's Tower.md")
    assert_equal 'wizards-tower', slug("Wizard’s Tower.md")
  end

  def test_punctuation_is_dropped
    assert_equal 'armor-class-ac-and-magic-cancellation-mc', slug('Armor Class (AC) and Magic Cancellation (MC).md')
    assert_equal 'items/battle-axe', slug('Items/Battle-axe.md')
    assert_equal 'items/novels/guards-guards', slug('Items/Novels/Guards! Guards!.md')
  end

  def test_unicode_punctuation_becomes_hyphens
    assert_equal 'known-issues-in-modern-windows-port-net-maui-winui-3',
                 slug("Known Issues in Modern Windows Port (.NET MAUI ∕ WinUI 3).md")
    assert_equal 'development/data-file-locations-winui-3-version-net-maui',
                 slug("Development/Data File Locations (WinUI 3 Version – .NET MAUI).md")
  end

  def test_letters_are_folded_to_ascii
    assert_equal 'cafe', slug('Café.md')
    assert_equal 'strasse', slug('Straße.md')
    assert_equal 'aesir', slug('Æsir.md')
  end

  def test_home_is_empty
    assert_equal '', slug('Home.md')
  end

  def test_segment_without_letters_is_nil
    assert_nil slug('Items/!!!.md')
    assert_nil slug("日本.md")
  end

  def test_escape_path_matches_gollum
    assert_equal 'Guides/GnollHack%2C%20Gnoll%20Overseer%2C%20and%20GnollBench%20for%20Software%20Engineers.md',
                 GnollHackUrls.escape_path(GUIDE)
  end

  # Index

  def index(pages, others = [])
    GnollHackUrls::PageIndex.new(pages, others)
  end

  def test_collision_group_falls_back_as_a_whole
    idx = index(['Battle Axe.md', 'Battle-axe.md', 'Home.md'])
    assert_equal({ 'Battle Axe.md' => :collision, 'Battle-axe.md' => :collision }, idx.fallbacks)
    assert_equal({ 'battle-axe' => ['Battle Axe.md', 'Battle-axe.md'] }, idx.collisions)
    assert_nil idx.slug_for('Battle-axe.md')
    assert_nil idx.page_for_slug('battle-axe')
    assert_equal '/Battle%20Axe.md', idx.canonical_path('Battle Axe.md')
    assert_equal '/Battle-axe.md', idx.canonical_path('Battle-axe.md')
  end

  def test_reserved_first_segment_falls_back
    idx = index(['Gollum.md', 'uploads/Notes.md', 'Gollum Tips.md'])
    assert_equal :reserved, idx.fallbacks['Gollum.md']
    assert_equal :reserved, idx.fallbacks['uploads/Notes.md']
    assert_equal 'gollum-tips', idx.slug_for('Gollum Tips.md')
  end

  def test_empty_segment_falls_back
    idx = index(['Items/!!!.md'])
    assert_equal({ 'Items/!!!.md' => :empty_segment }, idx.fallbacks)
    assert_equal '/Items/%21%21%21.md', idx.canonical_path('Items/!!!.md')
  end

  def test_slug_equal_to_a_file_falls_back
    idx = index(['License.md', 'Home.md'], ['LICENSE'])
    assert_equal({ 'License.md' => :file_conflict }, idx.fallbacks)
    assert_equal '/License.md', idx.canonical_path('License.md')
  end

  def test_canonical_paths
    idx = index(['Home.md', 'Items/Battle-axe.md'])
    assert_equal '/', idx.canonical_path('Home.md')
    assert_equal '/items/battle-axe', idx.canonical_path('Items/Battle-axe.md')
    assert_equal '', idx.slug_for('Home.md')
    assert idx.home?
  end

  def test_unknown_path_is_nil
    idx = index(['Home.md'])
    assert_nil idx.canonical_path('_Sidebar.md')
    assert_nil idx.slug_for('_Sidebar.md')
  end

  def test_legacy_lookup
    idx = index(['Items/Battle-axe.md', 'Home.md'])
    assert_equal 'Items/Battle-axe.md', idx.page_for_legacy('Items/Battle-axe.md')
    assert_equal 'Items/Battle-axe.md', idx.page_for_legacy('Items/Battle-axe')
    assert_equal 'Items/Battle-axe.md', idx.page_for_legacy('items/battle-axe.MD')
    assert_equal 'Home.md', idx.page_for_legacy('HOME')
    assert_nil idx.page_for_legacy('Items/Pick-axe')
  end

  def test_legacy_lookup_prefers_exact_match_and_refuses_ambiguity
    idx = index(['Notes/Foo.md', 'notes/foo.md'])
    assert_equal 'Notes/Foo.md', idx.page_for_legacy('Notes/Foo.md')
    assert_equal 'notes/foo.md', idx.page_for_legacy('notes/foo')
    assert_nil idx.page_for_legacy('NOTES/FOO.md')
  end

  # Router

  def router(pages = ['Home.md', 'Items/Battle-axe.md', 'Battle Axe.md', 'Battle-axe.md', GUIDE])
    GnollHackUrls::Router.new(index(pages))
  end

  def route(path, query = '', r = router)
    r.route(path, query)
  end

  def test_root_rewrites_to_home
    assert_equal [:rewrite, '/Home.md'], route('/')
    assert_equal [:pass], route('/', '', router(['Items/Battle-axe.md']))
  end

  def test_slug_rewrites
    assert_equal [:rewrite, '/Items/Battle-axe.md'], route('/items/battle-axe')
    assert_equal [:rewrite, "/#{GnollHackUrls.escape_path(GUIDE)}"],
                 route('/guides/gnollhack-gnoll-overseer-and-gnollbench-for-software-engineers')
  end

  def test_raw_slug_rewrites_and_raw_legacy_passes
    assert_equal [:rewrite, '/Items/Battle-axe.md'], route('/items/battle-axe', 'raw')
    assert_equal [:pass], route('/Items/Battle-axe.md', 'raw')
    assert_equal [:pass], route('/items/battle-axe/', 'raw')
  end

  def test_legacy_paths_redirect_with_query
    assert_equal [:redirect, '/items/battle-axe'], route('/Items/Battle-axe.md')
    assert_equal [:redirect, '/items/battle-axe'], route('/Items/Battle-axe')
    assert_equal [:redirect, '/items/battle-axe?foo=1'], route('/Items/Battle-axe.md', 'foo=1')
    assert_equal [:redirect, '/guides/gnollhack-gnoll-overseer-and-gnollbench-for-software-engineers'],
                 route("/#{GnollHackUrls.escape_path(GUIDE)}")
  end

  def test_legacy_paths_in_other_case_redirect
    assert_equal [:redirect, '/items/battle-axe'], route('/items/battle-axe.md')
    assert_equal [:redirect, '/'], route('/HOME.md')
  end

  def test_trailing_slash_redirects
    assert_equal [:redirect, '/items/battle-axe'], route('/Items/Battle-axe.md/')
    assert_equal [:redirect, '/items/battle-axe'], route('/items/battle-axe/')
    assert_equal [:redirect, '/'], route('/Home/')
  end

  def test_uppercase_slug_redirects
    assert_equal [:redirect, '/items/battle-axe'], route('/ITEMS/BATTLE-AXE')
  end

  def test_home_paths_redirect_to_root
    assert_equal [:redirect, '/'], route('/Home.md')
    assert_equal [:redirect, '/'], route('/Home')
    assert_equal [:redirect, '/'], route('/home')
  end

  def test_other_paths_pass
    ['/gollum/history/Home.md', '/.gollum/css/x.css', '/uploads/x.webp', "/Home.md/#{SHA}",
     '/Battle-axe.md', '/Battle%20Axe.md', '/No-Such-Page', '/robots.txt', '/sitemap.xml'].each do |path|
      assert_equal [:pass], route(path), path
    end
  end

  def test_malformed_paths_pass
    assert_equal [:pass], route('/%E4')
    assert_equal [:pass], route('/%zz')
  end

  def test_passthrough_needs_no_index
    assert GnollHackUrls.passthrough?('/gollum/overview')
    assert GnollHackUrls.passthrough?('/uploads/a.webp')
    assert GnollHackUrls.passthrough?('/Items/.hidden/x')
    refute GnollHackUrls.passthrough?('/')
    refute GnollHackUrls.passthrough?('/items/battle-axe')
  end

  # partition_paths

  def test_partition_paths
    paths = ['Home.md', 'Items/Battle-axe.md', '_Sidebar.md', '_Footer.md', 'Guides/_Sidebar2.md', 'LICENSE',
             'uploads/a.webp', '.agents/x.md', 'Items/.hidden/y.md', '_Template.md']
    pages, others = GnollHackUrls.partition_paths(paths, %w[md txt], %w[Header Footer Sidebar])
    assert_equal ['Home.md', 'Items/Battle-axe.md', '_Template.md'], pages
    assert_equal ['_Sidebar.md', '_Footer.md', 'Guides/_Sidebar2.md', 'LICENSE', 'uploads/a.webp'], others
  end

  # file_signature

  def test_file_signature
    Dir.mktmpdir('gnollhack-urls') do |dir|
      a = File.join(dir, 'a')
      b = File.join(dir, 'b')
      File.binwrite(a, 'one')
      first = GnollHackUrls.file_signature([a, b])
      assert_equal first, GnollHackUrls.file_signature([a, b])
      assert_nil first[1]

      File.binwrite(a, 'two')
      later = File.mtime(a) + 5
      File.utime(later, later, a)
      refute_equal first, GnollHackUrls.file_signature([a, b])

      before = GnollHackUrls.file_signature([a, b])
      File.binwrite(b, 'x')
      appeared = GnollHackUrls.file_signature([a, b])
      refute_equal before, appeared

      File.delete(b)
      refute_equal appeared, GnollHackUrls.file_signature([a, b])
    end
  end
end
