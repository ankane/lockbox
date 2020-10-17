module Lockbox
  class XChaCha20
    def initialize(key)
      Utils.check_key(key, size: self.class.key_bytes)

      @key = key
    end

    def encrypt(nonce, message, associated_data)
      ""
    end

    def decrypt(nonce, ciphertext, associated_data)
      ""
    end
  end
end
