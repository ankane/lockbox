class Lockbox
  class AES_GCM
    CHUNK_SIZE = 4096

    def initialize(key)
      raise ArgumentError, "Key must be 32 bytes" unless key && key.bytesize == 32
      raise ArgumentError, "Key must be binary" unless key.encoding == Encoding::BINARY

      @key = key
    end

    def encrypt(nonce, message, associated_data)
      cipher = OpenSSL::Cipher.new("aes-256-gcm")
      cipher.encrypt
      cipher.key = @key
      cipher.iv = nonce
      # From Ruby 2.5.3 OpenSSL::Cipher docs:
      # If no associated data shall be used, this method must still be called with a value of ""
      # In encryption mode, it must be set after calling #encrypt and setting #key= and #iv=
      cipher.auth_data = associated_data || ""

      ciphertext = String.new
      while !message.eof?
        ciphertext << cipher.update(message.read(CHUNK_SIZE))
      end
      ciphertext << cipher.final + cipher.auth_tag

      ciphertext
    end

    def decrypt(nonce, ciphertext, associated_data)
      ciphertext.seek(-auth_tag_bytes, IO::SEEK_END)
      auth_tag_pos = ciphertext.pos
      auth_tag = ciphertext.read
      ciphertext.pos = nonce_bytes

      fail_decryption if nonce.to_s.bytesize != nonce_bytes
      fail_decryption if auth_tag.to_s.bytesize != auth_tag_bytes

      cipher = OpenSSL::Cipher.new("aes-256-gcm")
      cipher.decrypt
      cipher.key = @key
      cipher.iv = nonce
      cipher.auth_tag = auth_tag
      # From Ruby 2.5.3 OpenSSL::Cipher docs:
      # If no associated data shall be used, this method must still be called with a value of ""
      # When decrypting, set it only after calling #decrypt, #key=, #iv= and #auth_tag= first.
      cipher.auth_data = associated_data || ""

      begin
        plaintext = String.new
        loop do
          read_bytes = auth_tag_pos - ciphertext.pos
          if read_bytes > CHUNK_SIZE
            read_bytes = CHUNK_SIZE
          elsif read_bytes <= 0
            break
          end
          plaintext << cipher.update(ciphertext.read(read_bytes))
        end
        plaintext << cipher.final
        plaintext
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
