require_relative "test_helper"

class RedisTest < Minitest::Test
  def setup
    redis.flushall
  end

  def test_works
    key = Lockbox.generate_key
    encrypted_redis = Lockbox::Redis.new(key: key, logger: $logger)
    encrypted_redis.set("hello", "world")
    assert_equal "world", encrypted_redis.get("hello")
    refute_equal "world", redis.get("hello")
  end

  def test_missing
    key = Lockbox.generate_key
    encrypted_redis = Lockbox::Redis.new(key: key, logger: $logger)
    assert_nil encrypted_redis.get("hello")
    assert_nil redis.get("hello")
  end

  def redis
    @redis ||= Redis.new(logger: $logger)
  end
end
