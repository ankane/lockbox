module Lockbox
  class Box
    NOT_SET = Object.new

    def initialize(key: nil, algorithm: nil, encryption_key: nil, decryption_key: nil, padding: false, associated_data: nil)
      raise ArgumentError, "Cannot pass both key and encryption/decryption key" if key && (encryption_key || decryption_key)

      key = Lockbox::Utils.decode_key(key) if key
      encryption_key, legacy_encryption = decode_hybrid_key(encryption_key) if encryption_key
      decryption_key, legacy_decryption = decode_hybrid_key(decryption_key) if decryption_key

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
        if encryption_key
          @encryption_box =
            if legacy_encryption
              nil
            else
              RbNaCl::Boxes::Sealed.from_public_key(encryption_key)
            end
        end
        if decryption_key
          @decryption_box =
            if legacy_decryption
              RbNaCl::Boxes::Curve25519XSalsa20Poly1305.new(decryption_key.byteslice(32..-1), decryption_key.byteslice(0, 32))
            else
              RbNaCl::Boxes::Sealed.from_private_key(decryption_key)
            end
        end
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
        Utils.raise_hybrid_error if @encryption_box.nil?
        @encryption_box.encrypt(message)
      when "xsalsa20"
        raise ArgumentError, "Associated data not supported with this algorithm" if associated_data
        nonce = generate_nonce(@box)
        nonce + @box.encrypt(nonce, message)
      else
        nonce = generate_nonce(@box)
        nonce + @box.encrypt(nonce, message, associated_data)
      end
    end

    def decrypt(ciphertext, associated_data: NOT_SET)
      associated_data = @associated_data if associated_data == NOT_SET
      message =
        case @algorithm
        when "hybrid"
          raise ArgumentError, "No decryption key set" unless defined?(@decryption_box)
          raise ArgumentError, "Associated data not supported with this algorithm" if associated_data
          if @decryption_box.is_a?(RbNaCl::Boxes::Sealed)
            @decryption_box.decrypt(ciphertext)
          else
            nonce, ciphertext = extract_nonce(@decryption_box, ciphertext)
            @decryption_box.decrypt(nonce, ciphertext)
          end
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

    def decode_hybrid_key(key)
      [Lockbox::Utils.decode_key(key), false]
    rescue Error => e
      begin
        [Lockbox::Utils.decode_key(key, size: 64), true]
      rescue Error
        raise e
      end
    end
  end
end
