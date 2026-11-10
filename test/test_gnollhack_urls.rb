require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'gnollhack_urls'

# Tests of slug derivation and URL encoding, the page index, the request router, path
# classification and the file signature in GnollHackUrls.
class TestGnollHackUrls < Minitest::Test
  GUIDE = 'Guides/GnollHack, Gnoll Overseer, and GnollBench for Software Engineers.md'
  SHA = '0123456789abcdef0123456789abcdef01234567'

  def slug(path)
    GnollHackUrls.slug(path)
  end

  def url_path(slug)
    GnollHackUrls.url_path(slug)
  end

  # Derivation

  def test_slug_of_example_page
    assert_equal 'Guides/GnollHack,_Gnoll_Overseer,_and_GnollBench_for_Software_Engineers', slug(GUIDE)
  end

  def test_spaces_become_underscores_and_case_is_kept
    assert_equal 'Item_Appearances', slug('Item Appearances.md')
    assert_equal 'iOS_and_macOS_Version', slug('iOS and macOS Version.md')
    assert_equal 'GnollHack.com_Cookie_Policy', slug('GnollHack.com Cookie Policy.md')
  end

  def test_punctuation_is_kept
    assert_equal 'Items/Battle-axe', slug('Items/Battle-axe.md')
    assert_equal "Dungeon/Wizard's_Tower", slug("Dungeon/Wizard's Tower.md")
    assert_equal 'Items/Novels/Guards!_Guards!', slug('Items/Novels/Guards! Guards!.md')
    assert_equal 'A:B', slug('A:B.md')
    assert_equal 'Etc.', slug('Etc..md')
  end

  def test_runs_of_spaces_and_underscores_are_one_underscore_trimmed_at_edges
    assert_equal 'A_B_C', slug('A  B _C.md')
    assert_equal 'Foo/Bar', slug('Foo/ Bar.md')
  end

  def test_home_is_empty
    assert_equal '', slug('Home.md')
  end

  def test_invalid_titles_are_nil
    ['A [b].md', 'A%41.md', 'A|B.md', '_.NET.md', 'Items/ .md', "A\tB.md", 'A#B.md'].each do |path|
      assert_nil slug(path), path
    end
  end

  def test_url_path
    assert_equal 'Dungeon/Wizard%27s_Tower', url_path("Dungeon/Wizard's_Tower")
    assert_equal 'Caf%C3%A9', url_path('Café')
    assert_equal 'Development/Data_File_Locations_(WinUI_3_Version_%E2%80%93_.NET_MAUI)',
                 url_path('Development/Data_File_Locations_(WinUI_3_Version_–_.NET_MAUI)')
    assert_equal 'A%26B%3FC%3DD%2BE', url_path('A&B?C=D+E')
    assert_equal 'Washington,_D.C._(x)!*@$;~', url_path('Washington,_D.C._(x)!*@$;~')
    assert_equal 'A%3AB', url_path('A:B')
    assert_equal 'Etc%2E', url_path('Etc.')
    assert_equal 'Vol._I', url_path('Vol._I')
    assert_equal 'b./c', url_path('b./c')
  end

  def test_url_path_is_ascii_and_decodes_back
    ["Dungeon/Wizard's_Tower", 'Café', 'A&B?C=D+E', 'Washington,_D.C._(x)!*@$;~', 'A:B', 'Etc.', 'b./c',
     'Known_Issues_(.NET_MAUI_∕_WinUI_3)', '"Quoted"_100%'].each do |s|
      url = url_path(s)
      assert url.ascii_only?, url
      assert_equal s, Rack::Utils.unescape_path(url), url
    end
  end

  def test_escape_path_matches_gollum
    assert_equal 'Guides/GnollHack%2C%20Gnoll%20Overseer%2C%20and%20GnollBench%20for%20Software%20Engineers.md',
                 GnollHackUrls.escape_path(GUIDE)
  end

  # Index

  def index(pages, others = [])
    GnollHackUrls::PageIndex.new(pages, others)
  end

  def test_collision_ignoring_case_falls_back_as_a_whole
    idx = index(['A B.md', 'a_b.md', 'Home.md'])
    assert_equal({ 'A B.md' => :collision, 'a_b.md' => :collision }, idx.fallbacks)
    assert_equal({ 'a_b' => ['A B.md', 'a_b.md'] }, idx.collisions)
    assert_nil idx.slug_for('A B.md')
    assert_nil idx.url_for('a_b.md')
    assert_nil idx.page_for_slug('A_B')
    assert_equal '/A%20B.md', idx.canonical_path('A B.md')
    assert_equal '/a_b.md', idx.canonical_path('a_b.md')
  end

  def test_reserved_first_segment_falls_back_ignoring_case
    idx = index(['gollum.md', 'Gollum.md', 'Uploads/Notes.md', 'Gollum Tips.md'])
    assert_equal :reserved, idx.fallbacks['gollum.md']
    assert_equal :reserved, idx.fallbacks['Gollum.md']
    assert_equal :reserved, idx.fallbacks['Uploads/Notes.md']
    assert_equal 'Gollum_Tips', idx.slug_for('Gollum Tips.md')
  end

  def test_invalid_title_falls_back
    idx = index(['A [b].md'])
    assert_equal({ 'A [b].md' => :invalid_title }, idx.fallbacks)
    assert_equal '/A%20%5Bb%5D.md', idx.canonical_path('A [b].md')
  end

  def test_slug_equal_to_a_file_falls_back
    idx = index(['License.md', 'Home.md'], ['LICENSE'])
    assert_equal({ 'License.md' => :file_conflict }, idx.fallbacks)
    assert_equal '/License.md', idx.canonical_path('License.md')
  end

  def test_slug_equal_to_another_page_falls_back
    idx = index(['Notes.txt.md', 'Notes.txt'])
    assert_equal({ 'Notes.txt.md' => :file_conflict }, idx.fallbacks)
    assert_equal 'Notes', idx.slug_for('Notes.txt')
    assert_equal '/Notes.txt.md', idx.canonical_path('Notes.txt.md')
  end

  def test_canonical_paths
    idx = index(['Home.md', 'Items/Battle-axe.md', "Dungeon/Wizard's Tower.md"])
    assert_equal '/', idx.canonical_path('Home.md')
    assert_equal '', idx.slug_for('Home.md')
    assert_equal '', idx.url_for('Home.md')
    assert_equal '/Items/Battle-axe', idx.canonical_path('Items/Battle-axe.md')
    assert_equal "Dungeon/Wizard's_Tower", idx.slug_for("Dungeon/Wizard's Tower.md")
    assert_equal 'Dungeon/Wizard%27s_Tower', idx.url_for("Dungeon/Wizard's Tower.md")
    assert_equal '/Dungeon/Wizard%27s_Tower', idx.canonical_path("Dungeon/Wizard's Tower.md")
    assert_equal "Dungeon/Wizard's Tower.md", idx.page_for_slug("Dungeon/Wizard's_Tower")
    assert_nil idx.page_for_slug('items/battle-axe')
    assert idx.home?
  end

  def test_unknown_path_is_nil
    idx = index(['Home.md'])
    assert_nil idx.canonical_path('_Sidebar.md')
    assert_nil idx.slug_for('_Sidebar.md')
    assert_nil idx.url_for('_Sidebar.md')
  end

  def test_legacy_lookup
    idx = index(['Item Appearances.md', 'Foo/ Bar.md', 'macOS Version.md', 'Home.md'])
    ['Item Appearances.md', 'Item Appearances', 'item_appearances', 'ITEM_APPEARANCES.MD', 'Item__Appearances',
     'item appearances'].each do |path|
      assert_equal 'Item Appearances.md', idx.page_for_legacy(path), path
    end
    assert_equal 'Foo/ Bar.md', idx.page_for_legacy('foo/bar')
    assert_equal 'macOS Version.md', idx.page_for_legacy('MacOS_Version')
    assert_equal 'Home.md', idx.page_for_legacy('HOME')
    assert_nil idx.page_for_legacy('Item_Appearance')
  end

  def test_legacy_lookup_prefers_exact_match_and_refuses_ambiguity
    idx = index(['Notes/Foo.md', 'notes/foo.md'])
    assert_equal 'Notes/Foo.md', idx.page_for_legacy('Notes/Foo.md')
    assert_equal 'notes/foo.md', idx.page_for_legacy('notes/foo')
    assert_nil idx.page_for_legacy('NOTES/FOO.md')
    assert_nil idx.page_for_legacy('NOTES/FOO')
  end

  def test_legacy_lookup_prefers_a_full_path
    assert_equal 'Notes.txt', index(['Notes.txt.md', 'Notes.txt']).page_for_legacy('Notes.txt')
    assert_equal 'Notes.txt', index(['Notes.txt', 'Notes.txt.md']).page_for_legacy('Notes.txt')
  end

  # Router

  WIZARD = "Dungeon/Wizard's Tower.md"
  THUD = 'Items/Novels/Thud!.md'

  def router(pages = ['Home.md', 'Items/Battle-axe.md', 'Item Appearances.md', 'iOS and macOS Version.md',
                      'A B.md', 'a_b.md', WIZARD, THUD, GUIDE])
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
    assert_equal [:rewrite, '/Items/Battle-axe.md'], route('/Items/Battle-axe')
    assert_equal [:rewrite, '/Item%20Appearances.md'], route('/Item_Appearances')
    assert_equal [:rewrite, "/#{GnollHackUrls.escape_path(GUIDE)}"],
                 route('/Guides/GnollHack,_Gnoll_Overseer,_and_GnollBench_for_Software_Engineers')
  end

  def test_every_encoding_of_a_slug_rewrites
    wizard = [:rewrite, "/#{GnollHackUrls.escape_path(WIZARD)}"]
    assert_equal wizard, route('/Dungeon/Wizard%27s_Tower')
    assert_equal wizard, route("/Dungeon/Wizard's_Tower")
    thud = [:rewrite, "/#{GnollHackUrls.escape_path(THUD)}"]
    assert_equal thud, route('/Items/Novels/Thud!')
    assert_equal thud, route('/Items/Novels/Thud%21')
  end

  def test_raw_slug_rewrites_and_raw_legacy_passes
    assert_equal [:rewrite, '/Items/Battle-axe.md'], route('/Items/Battle-axe', 'raw')
    assert_equal [:pass], route('/Items/Battle-axe.md', 'raw')
    assert_equal [:pass], route('/Items/Battle-axe/', 'raw')
  end

  def test_old_and_variant_paths_redirect_with_query
    ['/Item%20Appearances.md', '/Item%20Appearances', '/item_appearances', '/Item__Appearances',
     '/Item_Appearances/', '/ITEM%20APPEARANCES.MD'].each do |path|
      assert_equal [:redirect, '/Item_Appearances'], route(path), path
    end
    assert_equal [:redirect, '/Item_Appearances?foo=1'], route('/Item%20Appearances.md', 'foo=1')
    assert_equal [:redirect, '/Guides/GnollHack,_Gnoll_Overseer,_and_GnollBench_for_Software_Engineers'],
                 route("/#{GnollHackUrls.escape_path(GUIDE)}")
  end

  def test_other_letter_case_redirects_to_the_file_name_form
    assert_equal [:redirect, '/iOS_and_macOS_Version'], route('/IOS_and_macOS_Version')
    assert_equal [:redirect, '/Items/Battle-axe'], route('/ITEMS/BATTLE-AXE')
  end

  def test_redirect_carries_the_encoded_url
    assert_equal [:redirect, '/Dungeon/Wizard%27s_Tower'], route("/Dungeon/Wizard's%20Tower.md")
    assert_equal [:redirect, '/Dungeon/Wizard%27s_Tower'], route('/dungeon/wizard%27s_tower')
  end

  def test_home_paths_redirect_to_root
    ['/Home.md', '/Home', '/home', '/HOME.md', '/Home/'].each do |path|
      assert_equal [:redirect, '/'], route(path), path
    end
  end

  def test_double_encoded_path_passes
    assert_equal [:pass], route('/Dungeon/Wizard%2527s_Tower')
  end

  def test_other_paths_pass
    ['/gollum/history/Home.md', '/.gollum/css/x.css', '/uploads/x.webp', "/Home.md/#{SHA}",
     '/A%20B.md', '/a_b.md', '/A_B', '/No-Such-Page', '/robots.txt', '/sitemap.xml'].each do |path|
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
    refute GnollHackUrls.passthrough?('/Items/Battle-axe')
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
