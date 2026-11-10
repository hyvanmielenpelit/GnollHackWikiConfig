require 'minitest/autorun'
require 'gnollhack_front_door'

# Tests of the X-Azure-FDID check and the host pinning in GnollHackFrontDoor.
class TestGnollHackFrontDoor < Minitest::Test
  SITE = 'https://wiki.gnollhack.com'
  ID = '00000000-0000-0000-0000-000000000001'
  OTHER = '00000000-0000-0000-0000-000000000002'

  # parse_ids

  def test_nil_and_blank_give_no_ids
    assert_equal [], GnollHackFrontDoor.parse_ids(nil)
    assert_equal [], GnollHackFrontDoor.parse_ids('')
    assert_equal [], GnollHackFrontDoor.parse_ids('  , ,')
  end

  def test_one_id
    assert_equal [ID], GnollHackFrontDoor.parse_ids(ID)
  end

  def test_two_ids_are_stripped_and_lowercased
    value = " #{ID.upcase.tr('0', 'A')} ,  #{OTHER} "
    assert_equal [ID.tr('0', 'a'), OTHER], GnollHackFrontDoor.parse_ids(value)
  end

  # allowed?

  def test_no_ids_allows_everything
    assert GnollHackFrontDoor.allowed?({}, [])
    assert GnollHackFrontDoor.allowed?({ 'HTTP_X_AZURE_FDID' => OTHER }, [])
  end

  def test_matching_id_in_other_case_is_allowed
    id = ID.tr('0', 'a')
    assert GnollHackFrontDoor.allowed?({ 'HTTP_X_AZURE_FDID' => " #{id.upcase} " }, [id])
  end

  def test_missing_header_is_refused
    refute GnollHackFrontDoor.allowed?({}, [ID])
    refute GnollHackFrontDoor.allowed?({ 'HTTP_X_AZURE_FDID' => '' }, [ID])
  end

  def test_wrong_id_is_refused
    refute GnollHackFrontDoor.allowed?({ 'HTTP_X_AZURE_FDID' => OTHER }, [ID])
  end

  # pin_public_host

  def direct_env
    {
      'REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/gollum/feed/', 'HTTP_HOST' => 'origin.invalid',
      'SERVER_NAME' => 'origin.invalid', 'SERVER_PORT' => '8080', 'rack.url_scheme' => 'http',
      'HTTP_X_FORWARDED_HOST' => 'attacker.invalid', 'HTTP_X_FORWARDED_PROTO' => 'http',
      'HTTP_X_FORWARDED_PORT' => '8080', 'HTTP_FORWARDED' => 'host=attacker.invalid;proto=http'
    }
  end

  def test_request_without_header_is_unchanged
    env = direct_env
    assert_same env, GnollHackFrontDoor.pin_public_host(env, SITE)
  end

  def test_front_door_request_is_pinned_to_the_site
    env = direct_env.merge('HTTP_X_AZURE_FDID' => ID)
    pinned = GnollHackFrontDoor.pin_public_host(env, SITE)
    assert_equal 'wiki.gnollhack.com', pinned['HTTP_HOST']
    assert_equal 'wiki.gnollhack.com', pinned['HTTP_X_FORWARDED_HOST']
    assert_equal 'wiki.gnollhack.com', pinned['SERVER_NAME']
    assert_equal 'https', pinned['HTTP_X_FORWARDED_PROTO']
    assert_equal 'https', pinned['rack.url_scheme']
    assert_equal '443', pinned['SERVER_PORT']
    refute pinned.key?('HTTP_FORWARDED')
    refute pinned.key?('HTTP_X_FORWARDED_PORT')
    assert_equal '/gollum/feed/', pinned['PATH_INFO']
    assert_equal ID, pinned['HTTP_X_AZURE_FDID']
  end

  def test_argument_is_not_modified
    env = direct_env.merge('HTTP_X_AZURE_FDID' => ID)
    before = env.dup
    GnollHackFrontDoor.pin_public_host(env, SITE)
    assert_equal before, env
  end

  # public_location

  def test_path_location_is_joined_to_the_site
    assert_equal "#{SITE}/", GnollHackFrontDoor.public_location('/', SITE)
    assert_equal "#{SITE}/Wizard%27s_Tower", GnollHackFrontDoor.public_location('/Wizard%27s_Tower', "#{SITE}/")
  end

  def test_other_locations_are_unchanged
    assert_equal 'https://example.invalid/x', GnollHackFrontDoor.public_location('https://example.invalid/x', SITE)
    assert_equal '//example.invalid/x', GnollHackFrontDoor.public_location('//example.invalid/x', SITE)
    assert_equal 'Home', GnollHackFrontDoor.public_location('Home', SITE)
    assert_nil GnollHackFrontDoor.public_location(nil, SITE)
  end
end
