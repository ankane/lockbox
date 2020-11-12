module Lockbox
  class AES_GCM
    def initialize(key)
      raise ArgumentError, "Key must be 32 bytes" unless key && key.bytesize == 32
      raise ArgumentError, "Key must be binary" unless key.encoding == Encoding::BINARY

      @key = key
    end

    def encrypt(nonce, message, associated_data)
      cipher = OpenSSL::Cipher.new("aes-256-gcm")
      # do not change order of operations
      cipher.encrypt
      cipher.key = @key
      cipher.iv = nonce
      # From Ruby 2.5.3 OpenSSL::Cipher docs:
      # If no associated data shall be used, this method must still be called with a value of ""
      # In encryption mode, it must be set after calling #encrypt and setting #key= and #iv=
      cipher.auth_data = associated_data || ""

      ciphertext = String.new
      ciphertext << cipher.update(message) unless message.empty?
      ciphertext << cipher.final
      ciphertext << cipher.auth_tag
      ciphertext
    end

    def decrypt(nonce, ciphertext, associated_data)
      auth_tag, ciphertext = extract_auth_tag(ciphertext.to_s)

      fail_decryption if nonce.to_s.bytesize != nonce_bytes
      fail_decryption if auth_tag.to_s.bytesize != auth_tag_bytes

      cipher = OpenSSL::Cipher.new("aes-256-gcm")
      # do not change order of operations
      cipher.decrypt
      cipher.key = @key
      cipher.iv = nonce
      cipher.auth_tag = auth_tag
      # From Ruby 2.5.3 OpenSSL::Cipher docs:
      # If no associated data shall be used, this method must still be called with a value of ""
      # When decrypting, set it only after calling #decrypt, #key=, #iv= and #auth_tag= first.
      cipher.auth_data = associated_data || ""

      begin
        message = String.new
        message << cipher.update(ciphertext) unless ciphertext.to_s.empty?
        message << cipher.final
        message
      rescue OpenSSL::Cipher::CipherError
        fail_decryption
      end
    end

    def nonce_bytes
      12
    end

    # protect key
    def inspect
      to_s
    end

    private

    def auth_tag_bytes
      16
    end

    def extract_auth_tag(bytes)
      auth_tag = bytes.slice(-auth_tag_bytes..-1)
      [auth_tag, bytes.slice(0, bytes.bytesize - auth_tag_bytes)]
    end

    def fail_decryption
      raise DecryptionError, "Decryption failed"
    end
  end
end
