require_relative "test_helper"

class DalliTest < Minitest::Test
  def setup
    dalli.flush_all
  end

  def test_set_get
    encrypted_dalli.set("hello", "world")
    assert_equal "world", encrypted_dalli.get("hello")
    refute_equal "world", dalli.get("hello")
  end

  def dalli
    @dalli ||= Dalli::Client.new
  end

  def encrypted_dalli
    @encrypted_dalli ||= Lockbox::Dalli.new(key: Lockbox.generate_key)
  end
end
