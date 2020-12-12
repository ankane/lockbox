require "forwardable"
require "redis"

module Lockbox
  # don't extend Redis at the moment
  # so we can confirm operations are safe before adding
  class Redis
    extend Forwardable
    def_delegators :@redis, :flushall

    # TODO add option to blind index keys
    def initialize(key: nil, algorithm: nil, encryption_key: nil, decryption_key: nil, padding: false, previous_versions: nil, key_key: nil, **options)
      @lockbox = Lockbox.new(
        key: key,
        algorithm: algorithm,
        encryption_key: encryption_key,
        decryption_key: decryption_key,
        padding: padding,
        previous_versions: previous_versions
      )
      @redis = ::Redis.new(**options)
      @key_key = key_key
    end

    def set(key, value, **options)
      @redis.set(transform_key(key), encrypt(value), **options)
    end

    def get(key)
      decrypt(@redis.get(transform_key(key)))
    end

    def mset(*args)
      @redis.mset(args.map.with_index { |v, i| i % 2 == 1 ? encrypt(v) : v })
    end

    def mget(*keys, &blk)
      @redis.mget(*keys, &blk).map { |v| decrypt(v) }
    end

    def getset(key, value)
      decrypt(@redis.getset(transform_key(key), encrypt(value)))
    end

    private

    def transform_key(key)
      if @key_key
        BlindIndex.generate_bidx(key, key: @key_key)
      else
        key
      end
    end

    def encrypt(value)
      value.nil? ? value : @lockbox.encrypt(value)
    end

    def decrypt(value)
      value.nil? || value.empty? ? value : @lockbox.decrypt(value)
    end
  end
end
