require_relative "test_helper"

class RedisTest < Minitest::Test
  def setup
    redis.flushall
  end

  def test_set_get
    encrypted_redis.set("hello", "world")
    assert_equal "world", encrypted_redis.get("hello")
    refute_equal "world", redis.get("hello")
  end

  def test_set_nil
    encrypted_redis.set("hello", nil)
    assert_equal "", encrypted_redis.get("hello")
    assert_equal "", redis.get("hello")
  end

  def test_get_missing
    assert_nil encrypted_redis.get("hello")
    assert_nil redis.get("hello")
  end

  def test_getset
    encrypted_redis.set("hello", "world")
    assert_equal "world", encrypted_redis.getset("hello", "space")
    assert_equal "space", encrypted_redis.get("hello")
    refute_equal "space", redis.get("hello")
  end

  def test_mset_mget
    encrypted_redis.mset("k1", "v1", "k2", "v2", "k3", nil)
    assert_equal ["v1", "v2", "", nil], encrypted_redis.mget("k1", "k2", "k3", "missing")
    refute_equal "v1", redis.get("k1")
    refute_equal "v2", redis.get("k2")
    assert_equal "", redis.get("k3")
  end

  def redis
    @redis ||= Redis.new(logger: $logger)
  end

  def encrypted_redis
    @encrypted_redis ||= Lockbox::Redis.new(key: Lockbox.generate_key, logger: $logger)
  end
end
