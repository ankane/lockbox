require_relative "test_helper"

class RedisTest < Minitest::Test
  def setup
    redis.flushall
  end

  def test_works
    encrypted_redis.set("hello", "world")
    assert_equal "world", encrypted_redis.get("hello")
    refute_equal "world", redis.get("hello")
  end

  def test_missing
    assert_nil encrypted_redis.get("hello")
    assert_nil redis.get("hello")
  end

  def redis
    @redis ||= Redis.new(logger: $logger)
  end

  def encrypted_redis
    @encrypted_redis ||= Lockbox::Redis.new(
      key: Lockbox.generate_key,
      blind_index_key: BlindIndex.generate_key,
      logger: $logger
    )
  end
end
