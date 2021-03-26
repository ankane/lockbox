require_relative "test_helper"

class ModelTypesTest < Minitest::Test
  def setup
    skip if mongoid?
  end

  def test_type_string
    assert_attribute :country, "USA", format: "USA"
  end

  def test_type_string_utf8
    assert_attribute :country, "Łukasz", format: "Łukasz"
  end

  def test_type_string_non_utf8
    if mysql? && ActiveRecord::VERSION::STRING >= "6.1"
      error = assert_raises(ArgumentError) do
        assert_attribute :country, "Hi \255", format: "Hi \255"
      end
      assert_includes error.message, "invalid byte sequence in UTF-8"
    elsif postgresql? || mysql?
      error = assert_raises(ActiveRecord::StatementInvalid) do
        assert_attribute :country, "Hi \255", format: "Hi \255"
      end
      if postgresql?
        assert_includes error.message, "PG::CharacterNotInRepertoire"
      else
        assert_includes error.message, "Incorrect string value"
      end
    else
      assert_attribute :country, "Hi \255", format: "Hi \255"
    end
  end

  def test_type_boolean_true
    assert_attribute :active, true, format: "t"
  end

  def test_type_boolean_false
    assert_attribute :active, false, format: "f"
  end

  def test_type_boolean_bytesize
    assert_bytesize :active, true, false, size: 1
  end

  def test_type_boolean_invalid
    # non-falsey values are true
    assert_attribute :active, "invalid", expected: true
  end

  def test_type_boolean_empty_string
    assert_attribute :active, "", expected: nil
  end

  def test_type_date
    born_on = Date.current
    assert_attribute :born_on, born_on, format: born_on.strftime("%Y-%m-%d")
  end

  def test_type_date_bytesize
    assert_bytesize :born_on, Date.current, Date.current + 10000, size: 10
    assert_bytesize :born_on, Date.current, Date.current - 10000, size: 10
    assert_bytesize :born_on, Date.current, Date.parse("999-01-01"), size: 10
    refute_bytesize :born_on, Date.current, Date.parse("99999-01-01")
  end

  def test_type_date_invalid
    assert_attribute :born_on, "invalid", expected: nil
  end

  def test_type_datetime
    skip if mysql?

    signed_at = Time.current.round(6)
    assert_attribute :signed_at, signed_at, format: signed_at.utc.iso8601(9), time_zone: true
  end

  def test_type_datetime_bytesize
    assert_bytesize :signed_at, Time.current, Time.current + 100.years, size: 30
    assert_bytesize :signed_at, Time.current, Time.current - 100.years, size: 30
  end

  def test_type_datetime_invalid
    assert_attribute :signed_at, "invalid", expected: nil
  end

  def test_type_time
    skip if mysql?

    opens_at = Time.current.round(6).utc.change(year: 2000, month: 1, day: 1)
    assert_attribute :opens_at, opens_at, format: opens_at.utc.strftime("%H:%M:%S.%N")
  end

  def test_type_time_bytesize
    assert_bytesize :opens_at, Time.current, Time.current + 5.minutes, size: 18
  end

  def test_type_time_invalid
    assert_attribute :opens_at, "invalid", expected: nil
  end

  def test_type_integer
    sign_in_count = 10
    assert_attribute :sign_in_count, sign_in_count, format: [sign_in_count].pack("q>")
  end

  def test_type_integer_negative
    sign_in_count = -10
    assert_attribute :sign_in_count, sign_in_count, format: [sign_in_count].pack("q>")
  end

  def test_type_integer_bytesize
    assert_bytesize :sign_in_count, 10, 1_000_000_000, size: 8
    assert_bytesize :sign_in_count, -1_000_000_000, 1_000_000_000, size: 8
  end

  def test_type_integer_invalid
    assert_attribute :sign_in_count, "invalid", expected: 0
    assert_attribute :sign_in_count, "55invalid", expected: 55
  end

  def test_type_integer_in_range
    value = 2**63 - 1
    assert_attribute :sign_in_count, value, expected: value

    value = -(2**63)
    assert_attribute :sign_in_count, value, expected: value
  end

  def test_type_integer_out_of_range
    assert_raises ActiveModel::RangeError do
      User.create!(sign_in_count: 2**63)
    end

    assert_raises ActiveModel::RangeError do
      User.create!(sign_in_count2: 2**63)
    end

    assert_raises ActiveModel::RangeError do
      User.create!(sign_in_count: -(2**63 + 1))
    end

    assert_raises ActiveModel::RangeError do
      User.create!(sign_in_count2: -(2**63 + 1))
    end
  end

  def test_type_float
    skip if mysql?

    latitude = 10.12345678
    assert_attribute :latitude, latitude, format: [latitude].pack("G")
  end

  def test_type_float_negative
    skip if mysql?

    latitude = -10.12345678
    assert_attribute :latitude, latitude, format: [latitude].pack("G")
  end

  def test_type_float_bigdecimal
    skip if postgresql? || mysql?

    latitude = BigDecimal("123456789.123456789123456789")
    assert_attribute :latitude, latitude, expected: latitude.to_f, format: [latitude].pack("G")
  end

  def test_type_float_bytesize
    assert_bytesize :latitude, 10, 1_000_000_000.123, size: 8
    assert_bytesize :latitude, -1_000_000_000.123, 1_000_000_000.123, size: 8
  end

  def test_type_float_invalid
    assert_attribute :latitude, "invalid", expected: 0.0
    assert_attribute :latitude, "1.2invalid", expected: 1.2
  end

  def test_type_float_infinity
    skip if mysql?
    assert_attribute :latitude, Float::INFINITY, expected: Float::INFINITY, format: [Float::INFINITY].pack("G")
    assert_attribute :latitude, -Float::INFINITY, expected: -Float::INFINITY, format: [-Float::INFINITY].pack("G")
  end

  def test_type_float_nan
    skip if mysql?
    assert_attribute :latitude, Float::NAN, expected: Float::NAN, format: [Float::NAN].pack("G")
  end

  def test_type_binary
    video = SecureRandom.random_bytes(512)
    assert_attribute :video, video, format: video
  end

  def test_type_binary_bytesize
    refute_bytesize :video, SecureRandom.random_bytes(15), SecureRandom.random_bytes(16)
  end

  def test_type_json
    # json type isn't recognized with SQLite in Rails < 5.2
    skip if ActiveRecord::VERSION::STRING < "5.2"
    skip if mysql?

    data = {a: 1, b: "hi"}.as_json
    assert_attribute :data, data, format: data.to_json

    user = User.last
    new_data = {c: Time.now}.as_json
    user.data = new_data
    assert_equal [data, new_data], user.changes["data"]
    user.data2 = new_data
    assert_equal [data, new_data], user.changes["data2"]
  end

  def test_type_json_in_place
    user = User.create!(data2: {a: 1, b: "hi"})
    user.data2[:c] = "world"
    user.save!
    user = User.last
    assert_equal "world", user.data2["c"]
  end

  def test_type_json_save_twice
    data2 = {a: 1, b: "hi"}
    user = User.create!(data2: data2)
    user.reload
    user.save!

    user.data2
    user.save!

    new_data2 = {"a" => 1, "b" => "hi"}
    assert_equal new_data2, user.data2
  end

  def test_type_hash
    info = {a: 1, b: "hi"}
    assert_attribute :info, info, format: info.to_yaml

    # TODO see why keys are strings instead of symbols
    user = User.last
    new_info = {c: Time.now}
    user.info = new_info
    assert_equal [info.stringify_keys, new_info.stringify_keys], user.changes["info"]
    user.info2 = new_info
    assert_equal [info.stringify_keys, new_info.stringify_keys], user.changes["info2"]
  end

  def test_type_hash_invalid
    assert_raises ActiveRecord::SerializationTypeMismatch do
      User.create!(info: "invalid")
    end

    assert_raises ActiveRecord::SerializationTypeMismatch do
      User.create!(info2: "invalid")
    end
  end

  def test_type_hash_in_place
    user = User.create!(info2: {a: 1, b: "hi"})
    user.info2[:c] = "world"
    user.save!
    user = User.last
    assert_equal "world", user.info2[:c]
  end

  def test_type_hash_save_twice
    info2 = {a: 1, b: "hi"}
    user = User.create!(info2: info2)
    user.reload
    user.save!

    user.info2
    user.save!
    assert_equal info2, user.info2
  end

  def test_type_hash_empty
    user = User.create!
    assert_equal({}, user.info)
    assert_equal({}, user.info2)
  end

  def test_type_array
    coordinates = [1, 2, 3]
    assert_attribute :coordinates, coordinates, format: coordinates.to_yaml

    user = User.last
    new_coordinates = [1, 2, 3, 4, 5]
    user.coordinates = new_coordinates
    assert_equal [coordinates, new_coordinates], user.changes["coordinates"]
    user.coordinates2 = new_coordinates
    assert_equal [coordinates, new_coordinates], user.changes["coordinates2"]
  end

  def test_type_array_invalid
    assert_raises ActiveRecord::SerializationTypeMismatch do
      User.create!(coordinates: "invalid")
    end

    assert_raises ActiveRecord::SerializationTypeMismatch do
      User.create!(coordinates2: "invalid")
    end
  end

  def test_type_array_in_place
    user = User.create!(coordinates2: [1, 2, 3])
    user.coordinates2[3] = 4
    user.save!
    user = User.last
    assert_equal 4, user.coordinates2[3]
  end

  def test_type_array_save_twice
    coordinates2 = [1, 2, 3]
    user = User.create!(coordinates2: coordinates2)
    user.reload
    user.save!

    user.coordinates2
    user.save!
    assert_equal coordinates2, user.coordinates2
  end

  def test_type_array_empty
    user = User.create!
    assert_equal [], user.coordinates
    assert_equal [], user.coordinates2
  end

  def test_serialize_json
    properties = {a: 1, b: "hi"}.as_json
    assert_attribute :properties, properties, format: properties.to_json

    user = User.last
    new_properties = {c: Time.now}.as_json
    user.properties = new_properties
    assert_equal [properties, new_properties], user.changes["properties"]
    user.properties2 = new_properties
    assert_equal [properties, new_properties], user.changes["properties2"]
  end

  def test_serialize_json_in_place
    user = User.create!(properties2: {a: 1, b: "hi"})
    user.properties2[:c] = "world"
    user.save!
    user = User.last
    assert_equal "world", user.properties2["c"]
  end

  def test_serialize_hash
    settings = {a: 1, b: "hi"}
    assert_attribute :settings, settings, format: settings.to_yaml

    # TODO see why changes keys are strings instead of symbols
    user = User.last
    new_settings = {c: Time.now}
    user.settings = new_settings
    assert_equal [settings.stringify_keys, new_settings.stringify_keys], user.changes["settings"]
    user.settings2 = new_settings
    assert_equal [settings.stringify_keys, new_settings.stringify_keys], user.changes["settings2"]
  end

  def test_serialize_hash_in_place
    user = User.create!(settings2: {a: 1, b: "hi"})
    user.settings2[:c] = "world"
    user.save!
    user = User.last
    assert_equal "world", user.settings2[:c]
  end

  def test_serialize_hash_invalid
    assert_raises ActiveRecord::SerializationTypeMismatch do
      User.create!(settings: "invalid")
    end

    assert_raises ActiveRecord::SerializationTypeMismatch do
      User.create!(settings2: "invalid")
    end
  end

  def test_serialize_array
    messages = [1, 2, 3]
    assert_attribute :messages, messages, format: messages.to_yaml

    user = User.last
    new_messages = [4]
    user.messages = new_messages
    assert_equal [messages, new_messages], user.changes["messages"]
    user.messages2 = new_messages
    assert_equal [messages, new_messages], user.changes["messages2"]
  end

  def test_serialize_array_in_place
    user = User.create!(messages2: [1, 2, 3])
    user.messages2[3] = 4
    user.save!
    user = User.last
    assert_equal 4, user.messages2[3]
  end

  def test_serialize_array_invalid
    assert_raises ActiveRecord::SerializationTypeMismatch do
      User.create!(messages: "invalid")
    end

    assert_raises ActiveRecord::SerializationTypeMismatch do
      User.create!(messages2: "invalid")
    end
  end

  def test_type_inet_ipv4
    skip unless inet_supported?

    ip = IPAddr.new("127.0.0.1")
    assert_attribute :ip, ip, expected: ip, format: [0, 32, ip.hton, "\x00"*12].pack("cca4a12")
    assert_attribute :ip, ip.to_s, expected: ip, format: [0, 32, ip.hton, "\x00"*12].pack("cca4a12")
  end

  def test_type_inet_ipv4_prefix
    skip unless inet_supported?

    ip = IPAddr.new("127.0.0.0/24")
    assert_attribute :ip, ip, expected: ip, format: [0, 24, ip.hton, "\x00"*12].pack("cca4a12")
    assert_attribute :ip, "127.0.0.0/24", expected: ip, format: [0, 24, ip.hton, "\x00"*12].pack("cca4a12")
  end

  def test_type_inet_ipv6
    skip unless inet_supported?

    ip = IPAddr.new("::")
    assert_attribute :ip, ip, expected: ip, format: [1, 128, ip.hton].pack("cca16")
    assert_attribute :ip, ip.to_s, expected: ip, format: [1, 128, ip.hton].pack("cca16")
  end

  def test_type_inet_bytesize
    skip unless inet_supported?

    assert_bytesize :ip, "127.0.0.1", "255.255.255.255", size: 18
    assert_bytesize :ip, "::", "2606:4700:4700::64", size: 18
    assert_bytesize :ip, "127.0.0.0/24", "255.255.255.255", size: 18
  end

  def test_type_inet_invalid
    skip unless inet_supported?

    assert_attribute :ip, "invalid", expected: nil
  end

  def test_store
    credentials = {a: 1, b: "hi"}.as_json
    assert_attribute :credentials, credentials, format: credentials.to_json
    assert_attribute :username, "hello", check_nil: false
  end

  def test_type_custom
    assert_attribute :configuration, "USA", format: "USA!!"
  end

  def test_type_custom_attribute
    assert_attribute :config, "USA", format: "USA!!"
  end

  def test_type_migrating
    user = User.create!(conf: "Hi")
    key = Lockbox.attribute_key(table: "users", attribute: "conf_ciphertext")
    box = Lockbox.new(key: key, encode: true)
    assert_equal "Hi!!", box.decrypt_str(user.conf_ciphertext)
  end

  private

  def assert_attribute(attribute, value, format: nil, time_zone: false, check_nil: true, **options)
    attribute2 = "#{attribute}2".to_sym
    encrypted_attribute = "#{attribute2}_ciphertext"
    expected = options.key?(:expected) ? options[:expected] : value

    user = User.create!(attribute => value, attribute2 => value)
    assert_equal expected, user.send(attribute)
    assert_equal expected, user.send(attribute2)
    assert_nil user.send(encrypted_attribute) if expected.nil?

    # encoding
    if expected.is_a?(String)
      assert_equal expected.encoding, user.send(attribute).encoding
      assert_equal expected.encoding, user.send(attribute2).encoding
    end

    # time zone
    if time_zone
      assert_equal Time.zone, user.send(attribute).time_zone
      assert_equal Time.zone, user.send(attribute2).time_zone
    end

    user = User.last
    # SQLite does not support NaN
    assert_equal expected, user.send(attribute) unless expected.try(:nan?) && !ENV["ADAPTER"]
    assert_equal expected, user.send(attribute2)

    # encoding
    if expected.is_a?(String)
      assert_equal expected.encoding, user.send(attribute).encoding
      assert_equal expected.encoding, user.send(attribute2).encoding
    end

    # time zone
    if time_zone
      assert_equal Time.zone, user.send(attribute).time_zone
      assert_equal Time.zone, user.send(attribute2).time_zone
    end

    if format
      key = Lockbox.attribute_key(table: "users", attribute: encrypted_attribute)
      box = Lockbox.new(key: key, encode: true)
      assert_equal format.force_encoding(Encoding::BINARY), box.decrypt(user.send(encrypted_attribute))
    end

    if check_nil
      user.send("#{attribute2}=", nil)
      assert_nil user.send(encrypted_attribute)
    end
  end

  def assert_equal(exp, act)
    if exp.try(:nan?)
      assert act.try(:nan?), "Expected NaN"
    elsif exp.nil?
      assert_nil act
    else
      super
    end
  end

  def assert_bytesize(*args, size: nil)
    sizes = bytesizes(*args)
    assert_equal(*sizes)
    assert_equal size, sizes[0] - 12 - 16 if size
  end

  def refute_bytesize(*args)
    refute_equal(*bytesizes(*args))
  end

  def bytesizes(attribute, value1, value2)
    attribute = "#{attribute}2".to_sym
    encrypted_attribute = "#{attribute}_ciphertext"
    user1 = User.create!(attribute => value1)
    user2 = User.create!(attribute => value2)
    result1 = Base64.decode64(user1.send(encrypted_attribute)).bytesize
    result2 = Base64.decode64(user2.send(encrypted_attribute)).bytesize
    [result1, result2]
  end

  def mysql?
    ENV["ADAPTER"] == "mysql2"
  end

  def postgresql?
    ENV["ADAPTER"] == "postgresql"
  end

  def inet_supported?
    # no NoMethodError for prefix method
    # but it exists in Ruby 2.4 docs
    postgresql? && RUBY_VERSION.to_f > 2.4
  end
end
