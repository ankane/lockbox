require_relative "test_helper"

class LockboxTest < Minitest::Test
  def test_works
    options = {key: random_key}
    message = "it works!" * 10000
    ciphertext = Lockbox.encrypt(message, **options)
    assert_equal message, Lockbox.decrypt(ciphertext, **options)

    assert_equal Encoding::UTF_8, message.encoding
    assert_equal Encoding::BINARY, ciphertext.encoding
    assert_equal Encoding::BINARY, Lockbox.decrypt(ciphertext, **options).encoding
  end

  def test_same_message_different_ciphertext
    options = {key: random_key}
    message = "it works!"
    refute_equal Lockbox.encrypt(message, **options), Lockbox.encrypt(message, **options)
  end

  def test_encrypt_nil
    options = {key: random_key}
    assert_raises(TypeError) do
      Lockbox.encrypt(nil, **options)
    end
  end

  def test_decrypt_nil
    options = {key: random_key}
    assert_raises(TypeError) do
      Lockbox.decrypt(nil, **options)
    end
  end

  def test_encrypt_non_string
    options = {key: random_key}
    error = assert_raises(TypeError) do
      Lockbox.encrypt(1, **options)
    end
    assert_equal "can't convert Integer to String", error.message
  end

  def test_decrypt_non_string
    options = {key: random_key}
    error = assert_raises(TypeError) do
      Lockbox.decrypt(1, **options)
    end
    assert_equal "can't convert Integer to String", error.message
  end

  def test_encrypt_empty_string_aes_gcm
    options = {key: random_key}
    ciphertext = Lockbox.encrypt("", **options)
    assert_equal 12 + 16, ciphertext.bytesize
    assert_equal "", Lockbox.decrypt(ciphertext, **options)
  end

  def test_encrypt_empty_string_aes_gcm_low_level
    skip if jruby?

    ciphertext = Lockbox::AES_GCM.encrypt("\x0".b * 32, "\x0".b * 12, "", nil)
    assert_equal "530f8afbc74536b9a963b4f1c4cb738b", Lockbox.to_hex(ciphertext)
  end

  def test_encrypt_empty_string_aes_gcm_low_level_different_nonce
    ciphertext = Lockbox::AES_GCM.encrypt("\x0".b * 32, "\xff".b * 12, "", nil)
    assert_equal "51d37f94ccb639299b7ac25fe0bfd765", Lockbox.to_hex(ciphertext)
  end

  def test_encrypt_empty_string_xsalsa20
    options = {key: random_key, algorithm: "xsalsa20"}
    ciphertext = Lockbox.encrypt("", **options)
    assert_equal 24 + 16, ciphertext.bytesize
    assert_equal "", Lockbox.decrypt(ciphertext, **options)
  end

  def test_default_algorithm
    key = random_key
    encrypt_options = {key: key}
    message = "it works!" * 10000
    ciphertext = Lockbox.encrypt(message, **encrypt_options)
    decrypt_options = {key: key, algorithm: "aes-gcm"}
    assert_equal message, Lockbox.decrypt(ciphertext, **decrypt_options)
  end

  def test_aes_gcm_associated_data
    options = {key: random_key, algorithm: "aes-gcm"}
    message = "it works!"
    associated_data = "boom"
    ciphertext = Lockbox.encrypt(message, associated_data: associated_data, **options)
    assert_equal message, Lockbox.decrypt(ciphertext, associated_data: associated_data, **options)

    assert_raises(Lockbox::DecryptionError) do
      Lockbox.decrypt(ciphertext, associated_data: "bad", **options)
    end
  end

  def test_xsalsa20
    options = {key: random_key, algorithm: "xsalsa20"}
    message = "it works!" * 10000
    ciphertext = Lockbox.encrypt(message, **options)
    assert_equal message, Lockbox.decrypt(ciphertext, **options)

    assert_equal Encoding::UTF_8, message.encoding
    assert_equal Encoding::BINARY, ciphertext.encoding
    assert_equal Encoding::BINARY, Lockbox.decrypt(ciphertext, **options).encoding
  end

  def test_xsalsa20_associated_data
    options = {key: random_key, algorithm: "xsalsa20"}
    error = assert_raises(ArgumentError) do
      Lockbox.encrypt("it works!", associated_data: "boom", **options)
    end
    assert_equal "Associated data not supported with this algorithm", error.message
  end

  def test_xchacha20
    options = {key: random_key, algorithm: "xchacha20"}
    message = "it works!" * 10000
    ciphertext = Lockbox.encrypt(message, **options)
    assert_equal message, Lockbox.decrypt(ciphertext, **options)

    assert_equal Encoding::UTF_8, message.encoding
    assert_equal Encoding::BINARY, ciphertext.encoding
    assert_equal Encoding::BINARY, Lockbox.decrypt(ciphertext, **options).encoding
  end

  def test_xchacha20_associated_data
    options = {key: random_key, algorithm: "xchacha20"}
    message = "it works!"
    associated_data = "boom"
    ciphertext = Lockbox.encrypt(message, associated_data: associated_data, **options)
    assert_equal message, Lockbox.decrypt(ciphertext, associated_data: associated_data, **options)

    assert_raises(Lockbox::DecryptionError) do
      Lockbox.decrypt(ciphertext, associated_data: "bad", **options)
    end
  end

  def test_hybrid
    key_pair = Lockbox.generate_key_pair

    options = {algorithm: "hybrid", encryption_key: key_pair[:encryption_key]}
    message = "it works!" * 10000
    ciphertext = Lockbox.encrypt(message, **options)

    options = {algorithm: "hybrid", decryption_key: key_pair[:decryption_key]}
    assert_equal message, Lockbox.decrypt(ciphertext, **options)
  end

  def test_hybrid_swapped
    key_pair = Lockbox.generate_key_pair

    options = {algorithm: "hybrid", encryption_key: key_pair[:decryption_key]}
    message = "it works!" * 10000
    ciphertext = Lockbox.encrypt(message, **options)

    options = {algorithm: "hybrid", decryption_key: key_pair[:encryption_key]}
    assert_raises(Lockbox::DecryptionError) do
      Lockbox.decrypt(ciphertext, **options)
    end
  end

  def test_hybrid_no_encryption_key
    key_pair = Lockbox.generate_key_pair
    options = {algorithm: "hybrid", decryption_key: key_pair[:decryption_key]}
    error = assert_raises(ArgumentError) do
      Lockbox.encrypt("it works!", **options)
    end
    assert_equal "No encryption key set", error.message
  end

  def test_hybrid_no_decryption_key
    key_pair = Lockbox.generate_key_pair
    options = {algorithm: "hybrid", encryption_key: key_pair[:encryption_key]}
    error = assert_raises(ArgumentError) do
      Lockbox.decrypt("it works!", **options)
    end
    assert_equal "No decryption key set", error.message
  end

  def test_hybrid_legacy_encryption_key
    encryption_key = "0" * 128
    options = {algorithm: "hybrid", encryption_key: encryption_key}
    error = assert_raises(Lockbox::Error) do
      Lockbox.encrypt("it works!", **options)
    end
    assert_equal "Rotate your hybrid cryptography keys and data to address GHSA-586r-mm5q-xhg2", error.message
  end

  def test_hybrid_legacy_decryption_key
    a = RbNaCl::PrivateKey.generate
    b = RbNaCl::PrivateKey.generate
    decryption_key = Lockbox.to_hex(b.to_bytes + a.public_key.to_bytes)

    nonce = "0".b * 24
    message = "it works!" * 10000
    ciphertext = nonce + RbNaCl::Boxes::Curve25519XSalsa20Poly1305.new(b.public_key.to_bytes, a.to_bytes).encrypt(nonce, message)

    options = {algorithm: "hybrid", decryption_key: decryption_key}
    assert_equal message, Lockbox.decrypt(ciphertext, **options)
  end

  def test_bad_algorithm
    error = assert_raises(ArgumentError) do
      Lockbox.encrypt("", key: random_key, algorithm: "bad")
    end
    assert_includes error.message, "Unknown algorithm"
  end

  def test_bad_ciphertext
    options = {key: random_key}

    assert_raises(Lockbox::DecryptionError) do
      Lockbox.decrypt("0", **options)
    end

    assert_raises(Lockbox::DecryptionError) do
      Lockbox.decrypt("0"*16, **options)
    end

    assert_raises(Lockbox::DecryptionError) do
      Lockbox.decrypt("0"*100, **options)
    end
  end

  def test_bad_ciphertext_xchacha20
    options = {key: random_key, algorithm: "xchacha20"}

    assert_raises(Lockbox::DecryptionError) do
      Lockbox.decrypt("0", **options)
    end

    assert_raises(Lockbox::DecryptionError) do
      Lockbox.decrypt("0"*16, **options)
    end

    assert_raises(Lockbox::DecryptionError) do
      Lockbox.decrypt("0"*100, **options)
    end
  end

  def test_rotation
    key = random_key
    options = {key: key}
    message = "it works!"
    ciphertext = Lockbox.encrypt(message, **options)
    new_options = {key: random_key, previous_versions: [{key: key}]}
    assert_equal message, Lockbox.decrypt(ciphertext, **new_options)
  end

  def test_rotation_no_previous_version_tried
    ciphertext = Lockbox.encrypt("it works!", key: random_key)
    [[], [{master_key: random_key}]].each do |previous_versions|
      assert_raises(Lockbox::DecryptionError) do
        Lockbox.decrypt(ciphertext, key: random_key, previous_versions: previous_versions)
      end
    end
  end

  def test_rotation_padding_only
    key = random_key
    options = {key: key}
    message = "it works!"
    ciphertext = Lockbox.encrypt(message, **options)
    new_options = {key: key, padding: true, previous_versions: [{key: key}]}
    assert_equal message, Lockbox.decrypt(ciphertext, **new_options)

    # returning DecryptionError instead of PaddingError
    # is for end-user convenience, not for security
    assert_raises Lockbox::DecryptionError do
      Lockbox.decrypt(ciphertext, key: key, padding: true)
    end
  end

  def test_decrypt_utf8
    options = {key: random_key}
    message = "it works!"
    ciphertext = Lockbox.encrypt(message, **options)
    ciphertext.force_encoding(Encoding::UTF_8)
    assert_equal message, Lockbox.decrypt(ciphertext, **options)
  end

  def test_xsalsa20_decrypt_utf8
    options = {key: random_key, algorithm: "xsalsa20"}
    message = "it works!"
    ciphertext = Lockbox.encrypt(message, **options)
    ciphertext.force_encoding(Encoding::UTF_8)
    assert_equal message, Lockbox.decrypt(ciphertext, **options)
  end

  def test_xchacha20_decrypt_utf8
    options = {key: random_key, algorithm: "xchacha20"}
    message = "it works!"
    ciphertext = Lockbox.encrypt(message, **options)
    ciphertext.force_encoding(Encoding::UTF_8)
    assert_equal message, Lockbox.decrypt(ciphertext, **options)
  end

  def test_hex_key
    options = {key: SecureRandom.hex(32)}
    message = "it works!"
    ciphertext = Lockbox.encrypt(message, **options)
    assert_equal message, Lockbox.decrypt(ciphertext, **options)
  end

  def test_uppercase_hex_key
    options = {key: SecureRandom.hex(32).upcase}
    message = "it works!"
    ciphertext = Lockbox.encrypt(message, **options)
    assert_equal message, Lockbox.decrypt(ciphertext, **options)
  end

  def test_xsalsa20_hex_key
    options = {key: SecureRandom.hex(32), algorithm: "xsalsa20"}
    message = "it works!"
    ciphertext = Lockbox.encrypt(message, **options)
    assert_equal message, Lockbox.decrypt(ciphertext, **options)
  end

  def test_xchacha20_hex_key
    options = {key: SecureRandom.hex(32), algorithm: "xchacha20"}
    message = "it works!"
    ciphertext = Lockbox.encrypt(message, **options)
    assert_equal message, Lockbox.decrypt(ciphertext, **options)
  end

  def test_encrypt_file
    options = {key: SecureRandom.hex(32)}
    message = "it works!"

    file = Tempfile.new
    file.write(message)
    file.rewind

    ciphertext = Lockbox.encrypt(file, **options)
    assert_equal message, Lockbox.decrypt(ciphertext, **options)
  end

  def test_decrypt_file
    options = {key: SecureRandom.hex(32)}
    message = "it works!"
    ciphertext = Lockbox.encrypt(message, **options)

    file = Tempfile.new(encoding: Encoding::BINARY)
    file.write(ciphertext)
    file.rewind

    assert_equal message, Lockbox.decrypt(file, **options)
  end

  def test_attribute_key
    key = Lockbox.attribute_key(table: "users", attribute: "license", master_key: "0"*64)
    assert_equal "d96ffa3fe916b3a9b57d084f5781e95748333b877e32e6399e387d3d75b238a1", key
  end

  def test_attribute_key_cache
    Lockbox::KeyGenerator.clear_cache
    first = Lockbox.attribute_key(table: "users", attribute: "license", master_key: "0"*64, encode: false)
    assert first.frozen?
    assert_same first, Lockbox.attribute_key(table: "users", attribute: "license", master_key: "0"*64, encode: false)

    # cached value matches a fresh derivation
    Lockbox::KeyGenerator.clear_cache
    assert_equal first, Lockbox.attribute_key(table: "users", attribute: "license", master_key: "0"*64, encode: false)

    # keyed by master key, table, and attribute
    refute_equal first, Lockbox.attribute_key(table: "users", attribute: "license", master_key: "1"*64, encode: false)
    refute_equal first, Lockbox.attribute_key(table: "admins", attribute: "license", master_key: "0"*64, encode: false)
    refute_equal first, Lockbox.attribute_key(table: "users", attribute: "email", master_key: "0"*64, encode: false)
  end

  def test_attribute_key_cache_limit
    Lockbox::KeyGenerator.clear_cache
    (Lockbox::KeyGenerator::CACHE_LIMIT + 1).times do |i|
      Lockbox.attribute_key(table: "users", attribute: "a#{i}", master_key: "0"*64, encode: false)
    end
    assert_operator Lockbox::KeyGenerator.instance_variable_get(:@cache_size), :<=, Lockbox::KeyGenerator::CACHE_LIMIT
  ensure
    Lockbox::KeyGenerator.clear_cache
  end

  def test_attribute_key_encode_false
    key = Lockbox.attribute_key(table: "users", attribute: "license", master_key: "0"*64, encode: false)
    assert_equal ["d96ffa3fe916b3a9b57d084f5781e95748333b877e32e6399e387d3d75b238a1"].pack("H*"), key
  end

  def test_padding
    options = {key: random_key, padding: true}
    message = "it works!"
    ciphertext = Lockbox.encrypt(message, **options)
    # nonce + ciphertext + auth tag
    assert_equal 12 + 16 + 16, ciphertext.bytesize
    assert_equal message, Lockbox.decrypt(ciphertext, **options)
  end

  def test_padding_integer
    options = {key: random_key, padding: 13}
    message = "it works!"
    ciphertext = Lockbox.encrypt(message, **options)
    # nonce + ciphertext + auth tag
    assert_equal 12 + 13 + 16, ciphertext.bytesize
    assert_equal message, Lockbox.decrypt(ciphertext, **options)
  end

  def test_padding_invalid_size
    assert_raises ArgumentError do
      Lockbox.pad("hi", size: 0)
    end
  end

  def test_pad
    assert_equal "80000000000000000000000000000000", Lockbox.to_hex(Lockbox.pad(""))
    assert_equal "6162636465666768696a6b6c6d6e6f80", Lockbox.to_hex(Lockbox.pad("abcdefghijklmno"))
    assert_equal "6162636465666768696a6b6c6d6e6f7080000000000000000000000000000000", Lockbox.to_hex(Lockbox.pad("abcdefghijklmnop"))
  end

  def test_unpad
    assert_equal "", Lockbox.unpad(Lockbox.pad(""))
    assert_equal "abcdefghijklmno", Lockbox.unpad(Lockbox.pad("abcdefghijklmno"))
    assert_equal "abcdefghijklmnop", Lockbox.unpad(Lockbox.pad("abcdefghijklmnop"))
  end

  def test_unpad_invalid
    error = assert_raises(Lockbox::PaddingError) do
      Lockbox.unpad("hi")
    end
    assert_equal "Invalid padding", error.message
  end

  def test_encrypt_io
    options = {key: random_key}
    file = File.open("test/support/image.png", "rb")
    ciphertext_io = Lockbox.encrypt_io(file, **options)
    assert_equal "image.png", ciphertext_io.original_filename
    assert_nil ciphertext_io.content_type

    file.rewind
    ciphertext_io.rewind
    refute_equal file.read, ciphertext_io.read

    file.rewind
    ciphertext_io.rewind
    assert_equal file.read, Lockbox.decrypt_io(ciphertext_io, **options).read
  end

  def test_decrypt_str
    options = {key: random_key}
    message = "it works!" * 10000
    ciphertext = Lockbox.encrypt(message, **options)
    assert_equal message, Lockbox.decrypt_str(ciphertext, **options)

    assert_equal Encoding::UTF_8, message.encoding
    assert_equal Encoding::BINARY, ciphertext.encoding
    assert_equal Encoding::UTF_8, Lockbox.decrypt_str(ciphertext, **options).encoding
  end

  # ensure we can decrypt values from previous versions of Lockbox
  # other tests encrypt, then decrypt, so they won't catch this
  def test_decrypt_not_broken
    key = "0"*64
    options = {key: key, encode: true}
    assert_equal "it works!", Lockbox.decrypt("4nz8vb+KROTD6l9DvxanuOqn9OJWy7LpLDTKHHoM9Ll0lx+FAg==", **options)
  end

  def test_key_bad_length
    error = assert_raises(Lockbox::Error) do
      Lockbox.encrypt("", key: SecureRandom.hex(31))
    end
    assert_equal "Key must be 32 bytes (64 hex digits)", error.message
  end

  def test_key_bad_encoding
    error = assert_raises(Lockbox::Error) do
      Lockbox.encrypt("", key: SecureRandom.hex(16))
    end
    assert_equal "Key must use binary encoding", error.message
  end

  def test_master_key_bad_length
    with_master_key(SecureRandom.hex(31)) do
      error = assert_raises(Lockbox::Error) do
        Lockbox.attribute_key(table: "users", attribute: "test")
      end
      assert_equal "Master key must be 32 bytes (64 hex digits)", error.message
    end
  end

  def test_master_key_bad_encoding
    with_master_key(SecureRandom.hex(16)) do
      error = assert_raises(Lockbox::Error) do
        Lockbox.attribute_key(table: "users", attribute: "test")
      end
      assert_equal "Master key must use binary encoding", error.message
    end
  end

  private

  def random_key
    Lockbox.generate_key
  end
end
