module Lockbox
  module AES_GCM
    NONCE_BYTES = 12
    AUTH_TAG_BYTES = 16

    extend self

    def encrypt_message(key, message, associated_data)
      nonce = SecureRandom.random_bytes(NONCE_BYTES)
      nonce << encrypt(key, nonce, message, associated_data)
    end

    def decrypt_message(key, data, associated_data)
      size = data.bytesize
      fail_decryption if size < NONCE_BYTES + AUTH_TAG_BYTES

      decrypt_parts(
        key,
        data.byteslice(0, NONCE_BYTES),
        data.byteslice(NONCE_BYTES, size - NONCE_BYTES - AUTH_TAG_BYTES),
        data.byteslice(size - AUTH_TAG_BYTES, AUTH_TAG_BYTES),
        associated_data
      )
    end

    def encrypt(key, nonce, message, associated_data)
      check_key(key)

      cipher = OpenSSL::Cipher.new("aes-256-gcm")
      cipher.encrypt
      cipher.key = key
      cipher.iv = nonce
      cipher.auth_data = associated_data || ""

      ciphertext = message.empty? ? cipher.final : (cipher.update(message) << cipher.final)
      ciphertext << cipher.auth_tag
    end

    def decrypt(key, nonce, ciphertext, associated_data)
      ciphertext = ciphertext.to_s
      size = ciphertext.bytesize
      fail_decryption if size < AUTH_TAG_BYTES

      decrypt_parts(
        key,
        nonce,
        ciphertext.byteslice(0, size - AUTH_TAG_BYTES),
        ciphertext.byteslice(size - AUTH_TAG_BYTES, AUTH_TAG_BYTES),
        associated_data
      )
    end

    def nonce_bytes
      NONCE_BYTES
    end

    private

    def decrypt_parts(key, nonce, ciphertext, auth_tag, associated_data)
      check_key(key)
      fail_decryption if nonce.to_s.bytesize != NONCE_BYTES

      cipher = OpenSSL::Cipher.new("aes-256-gcm")
      cipher.decrypt
      cipher.key = key
      cipher.iv = nonce
      cipher.auth_tag = auth_tag
      cipher.auth_data = associated_data || ""

      begin
        ciphertext.empty? ? cipher.final : (cipher.update(ciphertext) << cipher.final)
      rescue OpenSSL::Cipher::CipherError
        fail_decryption
      end
    end

    def check_key(key)
      raise ArgumentError, "Key must be 32 bytes" unless key && key.bytesize == 32
      raise ArgumentError, "Key must be binary" unless key.encoding == Encoding::BINARY
    end

    def fail_decryption
      raise DecryptionError, "Decryption failed"
    end
  end
end
