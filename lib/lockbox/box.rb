module Lockbox
  class Box
    NOT_SET = Object.new

    def initialize(key: nil, algorithm: nil, encryption_key: nil, decryption_key: nil, padding: false, associated_data: nil)
      raise ArgumentError, "Cannot pass both key and encryption/decryption key" if key && (encryption_key || decryption_key)

      key = Lockbox::Utils.decode_key(key) if key
      encryption_key = Lockbox::Utils.decode_key(encryption_key, size: 64) if encryption_key
      decryption_key = Lockbox::Utils.decode_key(decryption_key, size: 64) if decryption_key

      algorithm ||= "aes-gcm"

      case algorithm
      when "aes-gcm"
        raise ArgumentError, "Missing key" unless key
        @box = AES_GCM.new(key)
      when "xchacha20"
        raise ArgumentError, "Missing key" unless key
        require "rbnacl"
        @box = RbNaCl::AEAD::XChaCha20Poly1305IETF.new(key)
      when "xsalsa20"
        raise ArgumentError, "Missing key" unless key
        require "rbnacl"
        @box = RbNaCl::SecretBoxes::XSalsa20Poly1305.new(key)
      when "hybrid"
        raise ArgumentError, "Missing key" unless encryption_key || decryption_key
        require "rbnacl"
        @encryption_box = RbNaCl::Boxes::Curve25519XSalsa20Poly1305.new(encryption_key.slice(0, 32), encryption_key.slice(32..-1)) if encryption_key
        @decryption_box = RbNaCl::Boxes::Curve25519XSalsa20Poly1305.new(decryption_key.slice(32..-1), decryption_key.slice(0, 32)) if decryption_key
      else
        raise ArgumentError, "Unknown algorithm: #{algorithm}"
      end

      @algorithm = algorithm
      @padding = padding == true ? 16 : padding
      @associated_data = associated_data
    end

    def encrypt(message, associated_data: NOT_SET)
      associated_data = @associated_data if associated_data == NOT_SET
      message = Lockbox.pad(message, size: @padding) if @padding
      case @algorithm
      when "hybrid"
        raise ArgumentError, "No encryption key set" unless defined?(@encryption_box)
        raise ArgumentError, "Associated data not supported with this algorithm" if associated_data
        nonce = generate_nonce(@encryption_box)
        ciphertext = @encryption_box.encrypt(nonce, message)
      when "xsalsa20"
        raise ArgumentError, "Associated data not supported with this algorithm" if associated_data
        nonce = generate_nonce(@box)
        ciphertext = @box.encrypt(nonce, message)
      else
        nonce = generate_nonce(@box)
        ciphertext = @box.encrypt(nonce, message, associated_data)
      end
      nonce + ciphertext
    end

    def decrypt(ciphertext, associated_data: NOT_SET)
      associated_data = @associated_data if associated_data == NOT_SET
      message =
        case @algorithm
        when "hybrid"
          raise ArgumentError, "No decryption key set" unless defined?(@decryption_box)
          raise ArgumentError, "Associated data not supported with this algorithm" if associated_data
          nonce, ciphertext = extract_nonce(@decryption_box, ciphertext)
          @decryption_box.decrypt(nonce, ciphertext)
        when "xsalsa20"
          raise ArgumentError, "Associated data not supported with this algorithm" if associated_data
          nonce, ciphertext = extract_nonce(@box, ciphertext)
          @box.decrypt(nonce, ciphertext)
        else
          nonce, ciphertext = extract_nonce(@box, ciphertext)
          @box.decrypt(nonce, ciphertext, associated_data)
        end
      message = Lockbox.unpad!(message, size: @padding) if @padding
      message
    end

    # protect key for xsalsa20, xchacha20, and hybrid
    def inspect
      to_s
    end

    private

    def generate_nonce(box)
      SecureRandom.random_bytes(box.nonce_bytes)
    end

    def extract_nonce(box, bytes)
      nonce_bytes = box.nonce_bytes
      nonce = bytes.slice(0, nonce_bytes)
      [nonce, bytes.slice(nonce_bytes..-1)]
    end
  end
end
