require "redis"

module Lockbox
  class Redis < ::Redis
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
      super(**options)
    end

    def set(key, value, **options)
      super(key, @lockbox.encrypt(value), **options)
    end

    def get(key)
      value = super
      value.nil? ? value : @lockbox.decrypt(value)
    end
  end
end
