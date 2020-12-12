require "redis"

module Lockbox
  # don't extend Redis at the moment
  # so we can confirm operations are safe before adding
  class Redis
    # TODO add option to blind index keys
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
      @redis.set(key, @lockbox.encrypt(value), **options)
    end

    def get(key)
      value = @redis.get(key)
      value.nil? ? value : @lockbox.decrypt(value)
    end
  end
end
