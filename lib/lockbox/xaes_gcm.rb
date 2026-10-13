module Lockbox
  class XAES_GCM
    def initialize(key)
      raise ArgumentError, "Key must be 32 bytes" unless key && key.bytesize == 32
      raise ArgumentError, "Key must be binary" unless key.encoding == Encoding::BINARY

      @key = key
    end

    def encrypt(nonce, message, associated_data)
      kx, nx = derive_key(@key, nonce)
      AES_GCM.new(kx).encrypt(nx, message, associated_data)
    end

    def decrypt(nonce, ciphertext, associated_data)
      nonce = nonce.to_str
      fail_decryption if nonce.bytesize != nonce_bytes

      kx, nx = derive_key(@key, nonce)
      AES_GCM.new(kx).decrypt(nx, ciphertext, associated_data)
    end

    def nonce_bytes
      24
    end

    # protect key
    def inspect
      to_s
    end

    private

    def fail_decryption
      raise DecryptionError, "Decryption failed"
    end

    # https://c2sp.org/XAES-256-GCM@v1.0.1#detailed-key-derivation-algorithm
    def derive_key(k, n)
      n = n.to_str
      raise ArgumentError, "Nonce must be 24 bytes" if n.bytesize != nonce_bytes
      raise ArgumentError, "Nonce must be binary" unless n.encoding == Encoding::BINARY

      l = aes256(k, "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
      k1 =
        if l[0].ord & 0x80 == 0
          lshift(l, 1)
        else
          xor(lshift(l, 1), "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x87")
        end
      m1 = "\x00\x01\x58\x00#{n.byteslice(0, 12)}"
      m2 = "\x00\x02\x58\x00#{n.byteslice(0, 12)}"
      kx = "#{aes256(k, xor(m1, k1))}#{aes256(k, xor(m2, k1))}"
      nx = n.byteslice(12..)
      [kx, nx]
    end

    def aes256(key, message)
      cipher = OpenSSL::Cipher.new("aes256")
      cipher.encrypt
      cipher.key = key
      cipher.iv = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
      cipher.update(message)
    end

    def xor(a, b)
      a.each_byte.zip(b.each_byte).map { |ai, bi| (ai ^ bi).chr }.join
    end

    def lshift(v, n)
      [((v.unpack1("H*").to_i(16) << n) & 0xffffffffffffffffffffffffffffffff).to_s(16)].pack("H*")
    end
  end
end
