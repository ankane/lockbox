module Lockbox
  class Curve25519XSalsa20
    def initialize(pk, sk)
      Utils.check_key(pk, size: self.class.public_key_bytes, name: "Public key") if pk
      Utils.check_key(sk, size: self.class.secret_key_bytes, name: "Secret key") if sk

      @pk = pk
      @sk = sk
    end

    def encrypt(nonce, message)
      raise "Missing public key" unless @pk
    end

    def decrypt(nonce, ciphertext)
      raise "Missing secret key" unless @sk
    end

    def nonce_bytes
      Libsodium.crypto_box_curve25519xsalsa20poly1305_noncebytes
    end

    def self.public_key_bytes
      Libsodium.crypto_box_curve25519xsalsa20poly1305_publickeybytes
    end

    def self.secret_key_bytes
      Libsodium.crypto_box_curve25519xsalsa20poly1305_secretkeybytes
    end

    # private
    def self.generate_key_pair
      require "fiddle"

      pk = Fiddle::Pointer.malloc(public_key_bytes)
      sk = Fiddle::Pointer.malloc(secret_key_bytes)

      status = Libsodium.crypto_box_curve25519xsalsa20poly1305_keypair(pk, sk)
      raise "Bad status: #{status}" unless status.zero?

      key_pair = {
        pk: pk.to_s(pk.size),
        sk: sk.to_s(sk.size)
      }

      Libsodium.sodium_memzero(pk, pk.size)
      Libsodium.sodium_memzero(sk, sk.size)

      key_pair
    end
  end
end
