module Lockbox
  module KeyGenerator
    C1 = ("\xB4"*32).freeze

    # Maximum number of entries in the key cache.
    CACHE_LIMIT = 1_000

    extend self

    # {master_key => { table => { attribute => key }}}.
    @cache = {}.freeze
    @cache_size = 0
    @cache_mutex = Mutex.new

    # pattern ported from CipherSweet
    # https://ciphersweet.paragonie.com/internals/key-hierarchy
    def attribute_key(master_key:, table:, attribute:)
      tables = @cache[master_key]
      attributes = tables[table] if tables
      key = attributes[attribute] if attributes
      return key if key

      raise ArgumentError, "Missing table for key generation" if table.to_s.empty?
      raise ArgumentError, "Missing attribute for key generation" if attribute.to_s.empty?

      key = hkdf(Lockbox::Utils.decode_key(master_key, name: "Master key"), salt: table.to_s, info: "#{C1}#{attribute}", length: 32, hash: "sha384").freeze
      cache_key(master_key, table, attribute, key)
      key
    end

    def clear_cache
      @cache_mutex.synchronize do
        @cache = {}.freeze
        @cache_size = 0
      end
    end


    private

    def cache_key(master_key, table, attribute, key)
      @cache_mutex.synchronize do
        cache, size = @cache_size >= CACHE_LIMIT ? [{}, 0] : [@cache.dup, @cache_size]
        tables = cache[master_key]&.dup || {}
        attributes = tables[table]&.dup || {}
        size += 1 unless attributes.key?(attribute)
        attributes[attribute] = key
        tables[table] = attributes.freeze
        cache[master_key] = tables.freeze
        @cache = cache.freeze
        @cache_size = size
      end
    end

    def hash_hmac(hash, ikm, salt)
      OpenSSL::HMAC.digest(hash, salt, ikm)
    end

    def hkdf(ikm, salt:, info:, length:, hash:)
      if defined?(OpenSSL::KDF.hkdf)
        return OpenSSL::KDF.hkdf(ikm, salt: salt, info: info, length: length, hash: hash)
      end

      prk = hash_hmac(hash, ikm, salt)

      # empty binary string
      t = String.new
      last_block = String.new
      block_index = 1
      while t.bytesize < length
        last_block = hash_hmac(hash, last_block + info + [block_index].pack("C"), prk)
        t << last_block
        block_index += 1
      end

      t[0, length]
    end
  end
end
