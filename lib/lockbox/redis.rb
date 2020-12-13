require "forwardable"
require "redis"

module Lockbox
  # don't extend Redis at the moment
  # so we can confirm operations are safe before adding
  class Redis
    extend Forwardable
    def_delegators :@redis, :del, :flushall, :keys, :dbsize, :info

    # TODO add option to blind keys
    def initialize(key: nil, algorithm: nil, encryption_key: nil, decryption_key: nil, padding: false, previous_versions: nil, **options)
      @lockbox = Lockbox.new(
        key: key,
        algorithm: algorithm,
        encryption_key: encryption_key,
        decryption_key: decryption_key,
        padding: padding,
        previous_versions: previous_versions
      )
      @redis = ::Redis.new(**options)
    end

    def set(key, value, **options)
      @redis.set(key, encrypt(value), **options)
    end

    def get(key)
      decrypt(@redis.get(key))
    end

    def mset(*args)
      @redis.mset(args.map.with_index { |v, i| i % 2 == 1 ? encrypt(v) : v })
    end

    def mget(*keys, &blk)
      @redis.mget(*keys, &blk).map { |v| decrypt(v) }
    end

    def getset(key, value)
      decrypt(@redis.getset(key, encrypt(value)))
    end

    private

    def encrypt(value)
      value.nil? ? value : @lockbox.encrypt(value)
    end

    def decrypt(value)
      value.nil? || value.empty? ? value : @lockbox.decrypt(value)
    end
  end
end
