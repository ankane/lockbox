module Lockbox
  class Curve25519XSalsa20
    def self.generate_key_pair
      require "fiddle"

      pk = Fiddle::Pointer.malloc(Libsodium.crypto_box_curve25519xsalsa20poly1305_publickeybytes)
      sk = Fiddle::Pointer.malloc(Libsodium.crypto_box_curve25519xsalsa20poly1305_secretkeybytes)

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
