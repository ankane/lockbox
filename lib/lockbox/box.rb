module Lockbox
  module Box
    extend self

    def encrypt(message, options)
      key = options[:key]
      encryption_key = options[:encryption_key]
      decryption_key = options[:decryption_key]
      raise ArgumentError, "Cannot pass both key and encryption/decryption key" if key && (encryption_key || decryption_key)

      key = Lockbox::Utils.decode_key(key) if key
      encryption_key, legacy_encryption = decode_hybrid_key(encryption_key) if encryption_key
      decryption_key, _ = decode_hybrid_key(decryption_key) if decryption_key

      algorithm = options[:algorithm] || "aes-gcm"
      cipher = cipher(algorithm, key, encryption_key, decryption_key)
      associated_data = options[:associated_data]
      padding = padding_size(options[:padding])

      message = Lockbox.pad(message, size: padding) if padding
      case algorithm
      when "aes-gcm"
        AES_GCM.encrypt_message(key, message, associated_data)
      when "hybrid"
        raise ArgumentError, "No encryption key set" unless encryption_key
        raise ArgumentError, "Associated data not supported with this algorithm" if associated_data
        Utils.raise_hybrid_error if legacy_encryption
        RbNaCl::Boxes::Sealed.from_public_key(encryption_key).encrypt(message)
      when "xsalsa20"
        raise ArgumentError, "Associated data not supported with this algorithm" if associated_data
        nonce = generate_nonce(cipher)
        nonce + cipher.encrypt(nonce, message)
      else
        nonce = generate_nonce(cipher)
        nonce + cipher.encrypt(nonce, message, associated_data)
      end
    end

    def decrypt(ciphertext, options)
      key = options[:key]
      encryption_key = options[:encryption_key]
      decryption_key = options[:decryption_key]
      raise ArgumentError, "Cannot pass both key and encryption/decryption key" if key && (encryption_key || decryption_key)

      key = Lockbox::Utils.decode_key(key) if key
      encryption_key, _ = decode_hybrid_key(encryption_key) if encryption_key
      decryption_key, legacy_decryption = decode_hybrid_key(decryption_key) if decryption_key

      algorithm = options[:algorithm] || "aes-gcm"
      cipher = cipher(algorithm, key, encryption_key, decryption_key)
      associated_data = options[:associated_data]
      padding = padding_size(options[:padding])

      message =
        case algorithm
        when "aes-gcm"
          AES_GCM.decrypt_message(key, ciphertext, associated_data)
        when "hybrid"
          raise ArgumentError, "No decryption key set" unless decryption_key
          raise ArgumentError, "Associated data not supported with this algorithm" if associated_data
          if legacy_decryption
            box = RbNaCl::Boxes::Curve25519XSalsa20Poly1305.new(decryption_key.byteslice(32..-1), decryption_key.byteslice(0, 32))
            nonce, ciphertext = extract_nonce(box, ciphertext)
            box.decrypt(nonce, ciphertext)
          else
            RbNaCl::Boxes::Sealed.from_private_key(decryption_key).decrypt(ciphertext)
          end
        when "xsalsa20"
          raise ArgumentError, "Associated data not supported with this algorithm" if associated_data
          nonce, ciphertext = extract_nonce(cipher, ciphertext)
          cipher.decrypt(nonce, ciphertext)
        else
          nonce, ciphertext = extract_nonce(cipher, ciphertext)
          cipher.decrypt(nonce, ciphertext, associated_data)
        end
      message = Lockbox.unpad!(message, size: padding) if padding
      message
    end

    private

    def cipher(algorithm, key, encryption_key, decryption_key)
      case algorithm
      when "aes-gcm"
        raise ArgumentError, "Missing key" unless key
        nil
      when "xchacha20"
        raise ArgumentError, "Missing key" unless key
        require "rbnacl"
        RbNaCl::AEAD::XChaCha20Poly1305IETF.new(key)
      when "xsalsa20"
        raise ArgumentError, "Missing key" unless key
        require "rbnacl"
        RbNaCl::SecretBoxes::XSalsa20Poly1305.new(key)
      when "hybrid"
        raise ArgumentError, "Missing key" unless encryption_key || decryption_key
        require "rbnacl"
        nil
      else
        raise ArgumentError, "Unknown algorithm: #{algorithm}"
      end
    end

    def padding_size(padding)
      padding == true ? 16 : padding
    end

    def generate_nonce(cipher)
      SecureRandom.random_bytes(cipher.nonce_bytes)
    end

    def extract_nonce(cipher, bytes)
      nonce_bytes = cipher.nonce_bytes
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
