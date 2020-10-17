module Lockbox
  class XSalsa20
    def initialize(key)
      Utils.check_key(key, size: self.class.key_bytes)

      @key = key
    end

    def encrypt(nonce, message)
      ""
    end

    def decrypt(nonce, ciphertext)
      ""
    end
  end
end
