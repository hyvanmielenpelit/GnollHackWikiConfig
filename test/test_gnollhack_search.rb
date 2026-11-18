require 'minitest/autorun'
require 'cgi'
require 'gnollhack_search'

# Tests of plain-text extraction, normalization, query parsing, matching,
# ranking, snippets, text fragments, exact-title lookup, suggestions and
# "did you mean" in GnollHackSearch.
class TestGnollHackSearch < Minitest::Test
  def text(source, path = 'Page.md')
    GnollHackSearch.page_text(source, path)
  end

  def doc(path, source, url = nil)
    GnollHackSearch.document(path, url || "/#{path.sub(/\.md\z/, '').tr(' ', '_')}", source)
  end

  def index(*docs)
    GnollHackSearch::Index.new(docs)
  end

  def wiki
    @wiki ||= index(
      doc('Potions.md', "Potions are liquids.\n\n## Healing\n\nA potion of healing heals."),
      doc('Items/Potion of healing.md', "A potion that heals you. Quaff it when hurt."),
      doc('Items/Potion of extra healing.md', "Heals more than a potion of healing."),
      doc('Monsters/Red dragon.md', "The red dragon breathes fire. Dragons hoard gold."),
      doc('Monsters/Dragons.md', "Every dragon is dangerous. A baby dragon grows up."),
      doc('Items/Elven mithril-coat.md', "Light armor. Elven mithril is rare."),
      doc('Smart Play.md', "Play smart: read the manual."),
      doc('Dungeon/Wizard\'s Tower.md', "The Wizard’s Tower holds the Wizard of Yendor."),
      doc('Races/Gnoll.md', "Gnolls are a playable race."),
      doc('Monsters/Gnoll.md', "A gnoll monster.")
    )
  end

  def titles(query, idx = wiki)
    idx.search(query)[:results].map { |r| r[:title] }
  end

  # Plain text

  def test_title_from_file_name
    title, headings, body = text("Some text.", 'Items/Potion of healing.md')
    assert_equal 'Potion of healing', title
    assert_equal [], headings
    assert_equal 'Some text.', body
  end

  def test_title_from_opening_h1_atx_and_setext
    assert_equal 'Archaeologist Quest', text("# Archaeologist Quest\n\nText", 'A.md')[0]
    assert_equal 'Closed Title', text("# Closed Title ##\n\nText", 'A.md')[0]
    assert_equal 'Setext Title', text("Setext Title\n===\n\nText", 'A.md')[0]
    assert_equal 'Bold Title', text("# **Bold** Title\n", 'A.md')[0]
  end

  def test_later_h1_is_a_heading_not_the_title
    title, headings, = text("Intro.\n\n# Later\n\nText", 'Page.md')
    assert_equal 'Page', title
    assert_equal ['Later'], headings
  end

  def test_front_matter_title_and_removal
    title, _, body = text("---\ntitle: Front Title\ndescription: x\n---\nBody text.", 'Page.md')
    assert_equal 'Front Title', title
    assert_equal 'Body text.', body
    assert_equal 'Page', text("---\ntitle: [unclosed\n---\nBody", 'Page.md')[0]
    assert_equal 'H1 Wins', text("---\ntitle: Front\n---\n# H1 Wins\n", 'Page.md')[0]
  end

  def test_headings_are_listed_and_kept_in_the_text
    _, headings, body = text("## First [[Link|Target]]\n\nPara.\n\n### Second ###\n\nSub\n---\n", 'P.md')
    assert_equal ['First Link', 'Second', 'Sub'], headings
    assert_equal 'First Link Para. Second Sub', body
  end

  def test_wikilinks
    body = text('See [[killer bees|/Monsters/Killer bee]], [[Potions]], [[/Items/Battle-axe]] and [[armor|#armor-quality]].')[2]
    assert_equal 'See killer bees, Potions, Battle-axe and armor.', body
    assert_equal 'A B', text('A [[_TOC_]] [[_TOC_|levels=2]] B')[2]
    assert_equal 'Icon Gnoll here', text('Icon [[/uploads/x.webp|alt=Gnoll]] here')[2]
    assert_equal 'No image', text('No [[/uploads/x.png]] image')[2]
  end

  def test_markdown_links_images_and_references
    body = text("A [link](https://x.com/a_(b) \"t\") and ![Alt text](/uploads/a.webp) and [ref][1].\n\n[1]: https://example.com")[2]
    assert_equal 'A link and Alt text and ref.', body.sub(' "t")', '')
  end

  def test_emphasis_code_quotes_lists_and_rules
    source = "> **Bold** and *em* and __strong__ and ~~gone~~\n\n- item one\n* item two\n1. first\n- [x] done\n\n***\n\nsnake_case `code` here"
    assert_equal 'Bold and em and strong and gone item one item two first done snake_case code here', text(source)[2]
  end

  def test_tables
    source = "| Name | Value |\n|------|:-----:|\n| Gnoll | 5 |\n"
    assert_equal 'Name Value Gnoll 5', text(source)[2]
  end

  def test_html_tags_comments_and_entities
    source = "<details><summary>More</summary>Hidden &amp; shown<br>next&nbsp;line 2&times;3 &lt;b&gt;</details>\n" \
             "<!-- a comment -->Shown<sup>2</sup> <img src=\"a.png\" alt=\"Picture\"> <center>C</center>"
    assert_equal 'More Hidden & shown next line 2×3 <b> Shown2 Picture C', text(source)[2]
  end

  def test_unclosed_comment_drops_the_rest
    assert_equal 'Before', text("Before <!-- never closed\nmore")[2]
  end

  def test_fenced_code_keeps_its_text_verbatim
    source = "Intro\n\n```bash\n# not a heading\n[[not a link]]\n```\n\n~~~\n<Configuration>\n~~~\nAfter"
    title, headings, body = text(source)
    assert_equal 'Page', title
    assert_empty headings
    assert_equal 'Intro # not a heading [[not a link]] <Configuration> After', body
  end

  def test_non_markdown_is_plain_text
    assert_equal ['Notes', [], '# Not a heading *x*'], text("# Not a heading\n*x*", 'Notes.txt')
  end

  def test_invalid_utf8_and_crlf
    assert_equal 'Bad byte here', text("Bad\r\nbyte \xFF here".b)[2]
  end

  def test_page_text_is_linear_on_hostile_input
    source = ('[' * 20_000) + ('<' * 20_000) + ('_' * 20_000) + ('#' * 20_000) + ("|\n" * 5_000)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    text(source)
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - elapsed, :<, 2
  end

  def test_folder_label
    assert_equal 'Items › Weapons', GnollHackSearch.folder_label('Items/Weapons/Sword.md')
    assert_equal '', GnollHackSearch.folder_label('Home.md')
  end

  # Normalization

  def test_normalize_keeps_length
    ['ß İ ﬁ Å ’ – ∕', "é ä", 'Ǆ ŉ ẞ Ω ﬀ ½ ①', 'GnollHack', "Wizard’s Tower — “quoted”"].each do |s|
      assert_equal s.length, GnollHackSearch.normalize(s).length, s.inspect
    end
  end

  def test_normalize_folds_case_accents_and_punctuation
    assert_equal "s i f a ' - /", GnollHackSearch.normalize('ß İ ﬁ Å ’ – ∕')
    assert_equal 'mjolnir', GnollHackSearch.normalize('Mjölnir')
    assert_equal "wizard's tower", GnollHackSearch.normalize('Wizard’s Tower')
  end

  def test_fold_title
    assert_equal 'potion of healing', GnollHackSearch.fold_title('  Potion_of  _Healing ')
  end

  # Query parsing

  def test_query_words_phrases_and_exclusions
    q = GnollHackSearch::Query.parse('Dragon "elven  mithril" -gnoll -"baby dragon" wizard\'s')
    assert_equal [%w[dragon], %w[elven mithril], %w[wizard s]], q.terms.map(&:words)
    assert_equal [%w[gnoll], %w[baby dragon]], q.excluded.map(&:words)
    assert_equal 'dragon elven mithril wizard s', q.text
  end

  def test_query_limits_and_empty_terms
    q = GnollHackSearch::Query.parse((1..15).map { |i| "w#{i}" }.join(' '))
    assert_equal 10, q.terms.length
    assert_equal 200, GnollHackSearch::Query.parse('a' * 500).raw.length
    assert GnollHackSearch::Query.parse('-- !!! "" -').empty?
    assert GnollHackSearch::Query.parse('-dragon').empty?
    assert GnollHackSearch::Query.parse('').empty?
  end

  def test_unclosed_quote_is_a_phrase
    assert_equal [%w[elven mithril]], GnollHackSearch::Query.parse('"elven mithril').terms.map(&:words)
  end

  # Matching

  def test_word_start_matching
    assert_includes titles('potion'), 'Potions'
    assert_empty titles('otion')
    refute_includes titles('art'), 'Smart Play'
    assert_includes titles('smart'), 'Smart Play'
  end

  def test_all_words_must_match
    assert_equal ['Potion of extra healing'], titles('potion extra')
  end

  def test_phrase_and_exclusion
    assert_equal ['Elven mithril-coat'], titles('"elven mithril"')
    assert_equal ['Red dragon'], titles('dragon -baby')
    assert_equal ['Dragons'], titles('dragon -"red dragon"')
  end

  def test_accents_and_apostrophes_match
    assert_includes titles('wizard’s tower'), "Wizard's Tower"
    assert_includes titles('WIZARD\'S'), "Wizard's Tower"
    idx = index(doc('Mjolnir.md', 'Mjölnir is a hammer.'))
    assert_equal ['Mjolnir'], titles('mjolnir', idx)
    assert_equal ['Mjolnir'], titles('MJÖLNIR', idx)
  end

  def test_empty_query_and_empty_index
    assert_equal 0, wiki.search('')[:total]
    assert_equal 0, index.search('x')[:total]
  end

  # Ranking

  def test_exact_title_ranks_first
    assert_equal 'Potions', titles('potions').first
    assert_equal 'Potion of healing', titles('potion of healing').first
  end

  def test_title_equal_but_for_a_plural_ranks_first
    assert_equal 'Potions', titles('potion').first
    assert_equal 'Dragons', titles('dragon').first
    assert GnollHackSearch.same_but_plural?('box', 'boxes')
    refute GnollHackSearch.same_but_plural?('potion', 'potionx')
    refute GnollHackSearch.same_but_plural?('potion', 'potion of')
  end

  def test_title_match_beats_body_mentions
    assert_equal ['Dragons', 'Red dragon'], titles('dragon').first(2).sort
  end

  def test_ties_break_by_shorter_title_then_alphabetically
    idx = index(doc('Abc.md', 'x word'), doc('Bc.md', 'x word'), doc('Ab.md', 'x word'))
    assert_equal %w[Ab Bc Abc], titles('word', idx)
  end

  def test_paging
    all = wiki.search('a')[:results].map { |r| r[:path] }
    page = wiki.search('a', offset: 2, limit: 2)
    assert_equal all.length, page[:total]
    assert_equal all[2, 2], page[:results].map { |r| r[:path] }
  end

  # Results, snippets and fragments

  def test_result_fields
    r = wiki.search('quaff')[:results].first
    assert_equal 'Items/Potion of healing.md', r[:path]
    assert_equal '/Items/Potion_of_healing', r[:url]
    assert_equal 'Items', r[:folder]
    assert_equal 'A potion that heals you. <mark>Quaff</mark> it when hurt.', r[:snippet_html]
    assert_equal 'A potion that heals you. Quaff it when hurt.', r[:snippet_text]
    assert_equal '#:~:text=that%20heals%20you.-,Quaff', r[:fragment]
    assert_equal 1, r[:count]
    assert_equal 0, r[:title_count]
  end

  def test_title_only_match_has_no_fragment
    r = wiki.search('extra')[:results].first
    assert_equal 'Potion of <mark>extra</mark> healing', r[:title_html]
    assert_equal '', r[:fragment]
    assert_equal 'Heals more than a potion of healing.', r[:snippet_html]
  end

  def test_prefix_match_fragment_takes_the_whole_word
    r = index(doc('A.md', 'Many dragons here')).search('drag')[:results].first
    assert_equal '#:~:text=Many-,dragons', r[:fragment]
    assert_equal 'Many <mark>drag</mark>ons here', r[:snippet_html]
  end

  def test_fragment_encodes_dash_comma_and_ampersand
    r = index(doc('A.md', 'well-known, R&D goal')).search('goal')[:results].first
    assert_equal '#:~:text=well%2Dknown%2C%20R%26D-,goal', r[:fragment]
  end

  def test_snippet_escapes_html_from_query_and_text
    idx = index(doc('X.md', 'Use &lt;script&gt; "quotes" & \'apostrophes\' safely'))
    r = idx.search('<script> "quotes" &')[:results].first
    assert_equal 'Use &lt;<mark>script</mark>&gt; &quot;<mark>quotes</mark>&quot; &amp; &#39;apostrophes&#39; safely', r[:snippet_html]
    title = index(doc('X.md', "---
title: <b>Bold</b> & Co
---
body")).search('bold')[:results].first[:title_html]
    assert_equal '&lt;b&gt;<mark>Bold</mark>&lt;/b&gt; &amp; Co', title
  end

  def test_long_text_snippet_is_windowed_at_word_boundaries
    body = ('lorem ipsum ' * 40) + 'the dragon sleeps ' + ('dolor sit ' * 40)
    r = index(doc('A.md', body)).search('dragon')[:results].first
    plain = r[:snippet_text]
    assert plain.start_with?('…') && plain.end_with?('…'), plain
    assert_operator plain.length, :<=, GnollHackSearch::SNIPPET_WINDOW + 4
    refute_match(/…\S*[a-z]…/, plain)
    assert_includes r[:snippet_html], '<mark>dragon</mark>'
    words = plain.delete('…').split(' ')
    assert words.all? { |w| %w[lorem ipsum the dragon sleeps dolor sit].include?(w) }, plain
  end

  def test_second_window_for_a_term_far_away
    body = 'alpha ' + ('filler ' * 60) + 'omega'
    r = index(doc('A.md', body)).search('alpha omega')[:results].first
    assert_includes r[:snippet_html], '<mark>alpha</mark>'
    assert_includes r[:snippet_html], '<mark>omega</mark>'
    assert_includes r[:snippet_text], ' … '
  end

  def test_untitled_match_snippet_is_the_start_of_the_text
    long = 'word ' * 100
    r = index(doc('Extra.md', long)).search('extra')[:results].first
    assert r[:snippet_text].end_with?('…')
    assert_operator r[:snippet_text].length, :<=, GnollHackSearch::SNIPPET_WINDOW + 1
  end

  # Go, suggestions, did you mean

  def test_go_target_is_unique_exact_title
    assert_equal '/Potions', wiki.go_target('potions')
    assert_equal '/Items/Potion_of_healing', wiki.go_target('Potion_of_healing ')
    assert_nil wiki.go_target('gnoll'), 'two pages are titled Gnoll'
    assert_nil wiki.go_target('potion')
  end

  def test_suggest_prefix_then_word_start
    assert_equal ['Potions', 'Potion of healing', 'Potion of extra healing'], wiki.suggest('pot').map(&:first)
    assert_equal ['Potion of healing', 'Potion of extra healing'], wiki.suggest('heal').map(&:first)
    assert_equal [['Red dragon', '/Monsters/Red_dragon']], wiki.suggest('red d')
    assert_equal 2, wiki.suggest('pot', limit: 2).length
    assert_empty wiki.suggest('')
  end

  def test_did_you_mean
    assert_equal 'Potions', wiki.did_you_mean('potionz').first&.fetch(:title)
    assert_empty wiki.did_you_mean('zzzzzz')
  end
end
