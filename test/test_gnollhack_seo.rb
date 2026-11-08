require 'minitest/autorun'
require 'gnollhack_seo'

# Tests of the page titles and meta descriptions in GnollHackSeo.
class TestGnollHackSeo < Minitest::Test
  PROSE = 'GnollHack is a roguelike game in which you explore a randomly generated dungeon.'
  PROSE_HTML = "<p>#{PROSE}</p>"

  def describer(html, url_path: 'Page.md', title: 'Page', metadata: {})
    GnollHackSeo::Describer.new(html: html, url_path: url_path, title: title, metadata: metadata)
  end

  # A description from front matter alone, which shortens it like any other.
  def override(text)
    describer('', metadata: { 'description' => text })
  end

  # Constants

  def test_constants
    assert_equal 160, GnollHackSeo::DESCRIPTION_MAX_LENGTH
    assert_equal ['description'], GnollHackSeo::METADATA_KEYS
    assert_operator GnollHackSeo::DEFAULT_DESCRIPTION.length, :<=, GnollHackSeo::DESCRIPTION_MAX_LENGTH
  end

  # Page titles

  def test_page_title_empty_or_nil_is_site_name
    assert_equal 'GnollHack Wiki', GnollHackSeo.page_title('')
    assert_equal 'GnollHack Wiki', GnollHackSeo.page_title(nil)
  end

  def test_page_title_site_name_is_not_repeated
    assert_equal 'GnollHack Wiki', GnollHackSeo.page_title('GnollHack Wiki')
  end

  def test_page_title_appends_site_name_after_en_dash
    assert_equal "Long sword – GnollHack Wiki", GnollHackSeo.page_title('Long sword')
  end

  # Rule 0: front matter override

  def test_override_plain_text
    d = describer(PROSE_HTML, metadata: { 'description' => 'A custom description of this page.' })
    assert_equal 'A custom description of this page.', d.description
    assert_equal :metadata, d.source
  end

  def test_override_is_decoded_to_plain_text
    d = describer(PROSE_HTML, metadata: { 'description' => 'A &amp; B <b>bold</b>' })
    assert_equal 'A & B bold', d.description
    assert_equal :metadata, d.source
  end

  def test_empty_override_falls_back_to_heuristics
    plain = describer(PROSE_HTML)
    d = describer(PROSE_HTML, metadata: { 'description' => '' })
    assert_equal plain.description, d.description
    assert_equal plain.source, d.source
    refute_equal :metadata, d.source
  end

  def test_non_string_override_falls_back_to_heuristics
    plain = describer(PROSE_HTML)
    [123, ['x']].each do |value|
      d = describer(PROSE_HTML, metadata: { 'description' => value })
      assert_equal plain.description, d.description
      assert_equal :prose, d.source
    end
  end

  def test_nil_metadata_is_accepted
    d = describer(PROSE_HTML, metadata: nil)
    assert_equal PROSE, d.description
    assert_equal :prose, d.source
  end

  def test_long_override_is_shortened
    d = override(('alpha beta gamma delta ' * 10).strip)
    assert_equal :metadata, d.source
    assert_operator d.description.length, :<=, GnollHackSeo::DESCRIPTION_MAX_LENGTH
  end

  def test_override_wins_over_home_page
    d = describer(PROSE_HTML, url_path: 'Home.md', title: 'Home',
                              metadata: { 'description' => 'Custom home page text.' })
    assert_equal 'Custom home page text.', d.description
    assert_equal :metadata, d.source
  end

  # Rule 1: special pages

  def test_home_page_uses_default_description
    d = describer(PROSE_HTML, url_path: 'Home.md', title: 'Home')
    assert_equal GnollHackSeo::DEFAULT_DESCRIPTION, d.description
    assert_equal :special, d.source
  end

  def test_underscore_page_uses_default_description
    d = describer(PROSE_HTML, url_path: '_Sidebar.md', title: '_Sidebar')
    assert_equal GnollHackSeo::DEFAULT_DESCRIPTION, d.description
    assert_equal :special, d.source
  end

  def test_page_titled_site_name_uses_default_description
    d = describer(PROSE_HTML, url_path: 'Main.md', title: 'GnollHack Wiki')
    assert_equal GnollHackSeo::DEFAULT_DESCRIPTION, d.description
    assert_equal :special, d.source
  end

  # Rule 2: ingress

  def test_ingress
    html = "<blockquote><p>\u{1F449} Installing GnollHack takes only a few minutes on every supported platform.</p></blockquote>" \
           '<p>Other text.</p>'
    d = describer(html, url_path: 'Install.md', title: 'Install')
    assert_equal 'Installing GnollHack takes only a few minutes on every supported platform.', d.description
    assert_equal :ingress, d.source
  end

  # Rule 3: caution

  def test_warning_block_quote_opening_the_page
    html = "<blockquote><p>⚠️ Warning: Saving games on a network drive can corrupt them without notice.</p></blockquote>" \
           '<p>Saved games are kept in the save folder of the game installation.</p>'
    d = describer(html, url_path: 'Saving.md', title: 'Saving')
    assert_equal 'Saving games on a network drive can corrupt them without notice.', d.description
    assert_equal :caution, d.source
  end

  def test_stop_sign_block_quote_opening_the_page
    html = "<blockquote><p>\u{1F6D1} Never quaff from a fountain while levitating over water.</p></blockquote>"
    d = describer(html, url_path: 'Fountains.md', title: 'Fountains')
    assert_equal 'Never quaff from a fountain while levitating over water.', d.description
    assert_equal :caution, d.source
  end

  # Rule 4: entry pages

  def test_item_entry_page
    html = '<h2>Melee Weapon: Long sword</h2>' \
           '<ul><li><strong>Weight:</strong> 40</li>' \
           '<li><strong>Base damage - Small:</strong> d8</li>' \
           '<li><strong>Base damage - Large:</strong> d12</li></ul>' \
           '<h2>Description</h2>' \
           '<p>The long sword is a common weapon for knights and valkyries.</p>'
    d = describer(html, url_path: 'Items/Long sword.md', title: 'Long sword')
    assert_equal 'Long sword: GnollHack melee weapon. The long sword is a common weapon for knights and valkyries. ' \
                 'Damage d8 vs. small, d12 vs. large, weight 40.', d.description
    assert_equal :entry, d.source
  end

  # Rule 5: link lists and the series of names

  def link_list_html(names)
    "<ul>#{names.map { |n| %(<li><a href="#{n}">#{n}</a></li>) }.join}</ul>"
  end

  def test_link_list_of_two_names
    d = describer(link_list_html(%w[Foo Bar]), url_path: 'Monsters.md', title: 'Monsters')
    assert_equal 'Monsters in GnollHack: Foo and Bar.', d.description
    assert_equal :link_list, d.source
  end

  def test_link_list_of_three_names_uses_oxford_comma
    d = describer(link_list_html(%w[Foo Bar Baz]), url_path: 'Monsters.md', title: 'Monsters')
    assert_equal 'Monsters in GnollHack: Foo, Bar, and Baz.', d.description
    assert_equal :link_list, d.source
  end

  def test_link_list_counts_names_not_shown
    names = %w[Ant Bat Cat Dog Eel Fox Gnu Hog]
    d = describer(link_list_html(names) + PROSE_HTML, url_path: 'Animals.md', title: 'Animals')
    assert_equal 'Animals in GnollHack: Ant, Bat, Cat, Dog, Eel, and 3 more.', d.description
    assert_equal :link_list, d.source
  end

  # Rule 6: prose

  def test_first_prose_paragraph
    d = describer("<h1>Gameplay</h1>#{PROSE_HTML}", url_path: 'Gameplay.md', title: 'Gameplay')
    assert_equal PROSE, d.description
    assert_equal :prose, d.source
  end

  def test_prose_in_later_section_is_not_used
    html = '<h2>Android</h2><p>Android is a trademark of Google LLC, used here with permission.</p>' \
           '<h2>Linux</h2><p>A long usable paragraph about Linux that ends with a period.</p>'
    d = describer(html, url_path: 'Download.md', title: 'Download')
    assert_equal GnollHackSeo::DEFAULT_DESCRIPTION, d.description
    assert_equal :default, d.source
  end

  def test_prose_in_first_section_is_used
    html = '<h2>Android</h2><p>GnollHack for Android is available from the Google Play store.</p>' \
           '<h2>Linux</h2><p>A long usable paragraph about Linux that ends with a period.</p>'
    d = describer(html, url_path: 'Download.md', title: 'Download')
    assert_equal 'GnollHack for Android is available from the Google Play store.', d.description
    assert_equal :prose, d.source
  end

  # Rule 7: a page that opens with a list

  def test_numbered_list_of_steps
    html = '<ol><li>Download the installer.</li><li>Run the installer.</li><li>Start the game.</li></ol>'
    d = describer(html, url_path: 'Installing.md', title: 'Installing')
    assert_equal 'Installing: Download the installer; run the installer; start the game.', d.description
    assert_equal :list, d.source
  end

  # Rule 8: nothing usable

  def test_default_when_nothing_is_usable
    d = describer('<h1>Stub</h1><p>Short.</p>', url_path: 'Stub.md', title: 'Stub')
    assert_equal GnollHackSeo::DEFAULT_DESCRIPTION, d.description
    assert_equal :default, d.source
  end

  def test_default_for_empty_page
    d = describer('', url_path: 'Empty.md', title: 'Empty')
    assert_equal GnollHackSeo::DEFAULT_DESCRIPTION, d.description
    assert_equal :default, d.source
  end

  # Shortening

  def test_text_of_max_length_is_unchanged
    text = "#{('word ' * 32).strip}."
    assert_equal 160, text.length
    assert_equal text, override(text).description
  end

  def test_text_over_max_length_is_cut
    text = "#{'word ' * 32}a"
    assert_equal 161, text.length
    d = override(text)
    assert_operator d.description.length, :<=, GnollHackSeo::DESCRIPTION_MAX_LENGTH
    assert d.description.end_with?("…")
  end

  def test_word_cut_keeps_unclosed_bracket_around_long_opening
    text = "Potions (#{('bubbling liquid ' * 15).strip}"
    d = override(text)
    assert_equal :metadata, d.source
    refute_equal "…", d.description
    assert_operator d.description.length, :>, 50
    assert_operator d.description.length, :<=, GnollHackSeo::DESCRIPTION_MAX_LENGTH
    assert d.description.start_with?('Potions (bubbling liquid')
    assert d.description.end_with?("…")
  end

  def test_no_sentence_cut_inside_bracket
    text = 'Wearing the amulet of life saving keeps its wearer alive through one otherwise fatal blow ' \
           '(the amulet then crumbles to dust. Nothing else remains of it afterward) and the wearer ' \
           'is restored to full health and strength after the blow lands'
    inner_end = text.index('dust.') + 'dust.'.length
    assert_operator inner_end, :>=, 90
    d = override(text)
    assert d.description.end_with?("…")
    assert_operator d.description.length, :>, inner_end
    assert_operator d.description.length, :<=, GnollHackSeo::DESCRIPTION_MAX_LENGTH
  end

  # Sentence breaks, observed where a long text is cut

  def test_sentence_break_after_period_and_closing_quote
    text = 'The shopkeeper greets every adventurer who enters the shop with the same words, ' \
           '"Welcome to my humble store, traveler." Prices rise for anyone wearing a dunce cap ' \
           'or a tourist shirt, and fall for nobody.'
    assert_equal 'The shopkeeper greets every adventurer who enters the shop with the same words, ' \
                 '"Welcome to my humble store, traveler."', override(text).description
  end

  def test_no_sentence_break_after_eg
    text = 'Some artifacts can be wished for by name in any game once the player has found a wand ' \
           'or scroll of wishing e.g. Excalibur or the Magicbane which every wizard hopes to get ' \
           'early on in the game before the quest begins'
    assert_operator text.index('e.g.'), :>=, 90
    d = override(text)
    refute d.description.end_with?('e.g.')
    assert d.description.include?('Excalibur')
    assert d.description.end_with?("…")
  end

  def test_no_sentence_break_after_vol
    text = 'The complete rules of the game are collected in the printed manual that ships with the ' \
           'deluxe box set as Vol. Two of the series and every chapter of it covers one part of the ' \
           'dungeon in great detail for new players'
    assert_operator text.index('Vol.'), :>=, 90
    d = override(text)
    refute d.description.end_with?('Vol.')
    assert d.description.include?('Vol. Two')
    assert d.description.end_with?("…")
  end
end
