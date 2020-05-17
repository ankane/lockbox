module Lockbox
  class KeyGenerator
    def initialize(master_key)
      @master_key = master_key
    end

    # pattern ported from CipherSweet
    # https://ciphersweet.paragonie.com/internals/key-hierarchy
    def attribute_key(table:, attribute:)
      raise ArgumentError, "Missing table for key generation" if table.to_s.empty?
      raise ArgumentError, "Missing attribute for key generation" if attribute.to_s.empty?

      c = "\xB4"*32
      hkdf(Lockbox::Utils.decode_key(@master_key, name: "Master key"), salt: table.to_s, info: "#{c}#{attribute}", length: 32, hash: "sha384")
    end

    private

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
