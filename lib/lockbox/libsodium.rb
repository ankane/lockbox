require "fiddle/import"

module Lockbox
  module Libsodium
    extend Fiddle::Importer

    libs = Lockbox.libsodium_lib.dup
    begin
      dlload Fiddle.dlopen(libs.shift)
    rescue Fiddle::DLError => e
      retry if libs.any?
      raise e if ENV["LOCKBOX_DEBUG"]

      if e.message.include?("libsodium.dylib")
        raise LoadError, "Libsodium not found. Run `brew install libsodium`"
      else
        raise LoadError, "Libsodium not found"
      end
    end

    # curve25519xsalsa20
    extern "size_t crypto_box_curve25519xsalsa20poly1305_publickeybytes(void)"
    extern "size_t crypto_box_curve25519xsalsa20poly1305_secretkeybytes(void)"
    extern "int crypto_box_curve25519xsalsa20poly1305_keypair(unsigned char *pk, unsigned char *sk)"
    extern "size_t crypto_box_curve25519xsalsa20poly1305_noncebytes(void)"

    # utils
    extern "void sodium_memzero(void * pnt, size_t len)"
  end
end
