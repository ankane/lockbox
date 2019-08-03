require_relative "test_helper"

class LockboxTest < Minitest::Test
  def test_works
    box = Lockbox.new(key: random_key)
    message = "it works!" * 10000
    ciphertext = box.encrypt(message)
    assert_equal message, box.decrypt(ciphertext)

    assert_equal Encoding::UTF_8, message.encoding
    assert_equal Encoding::BINARY, ciphertext.encoding
    assert_equal Encoding::BINARY, box.decrypt(ciphertext).encoding
  end

  def test_same_message_different_ciphertext
    box = Lockbox.new(key: random_key)
    message = "it works!"
    refute_equal box.encrypt(message), box.encrypt(message)
  end

  def test_encrypt_nil
    box = Lockbox.new(key: random_key)
    assert_raises(TypeError) do
      box.encrypt(nil)
    end
  end

  def test_decrypt_nil
    box = Lockbox.new(key: random_key)
    assert_raises(TypeError) do
      box.decrypt(nil)
    end
  end

  def test_default_algorithm
    key = random_key
    encrypt_box = Lockbox.new(key: key)
    message = "it works!" * 10000
    ciphertext = encrypt_box.encrypt(message)
    decrypt_box = Lockbox.new(key: key, algorithm: "aes-gcm")
    assert_equal message, decrypt_box.decrypt(ciphertext)
  end

  def test_aes_gcm_associated_data
    box = Lockbox.new(key: random_key, algorithm: "aes-gcm")
    message = "it works!"
    associated_data = "boom"
    ciphertext = box.encrypt(message, associated_data: associated_data)
    assert_equal message, box.decrypt(ciphertext, associated_data: associated_data)

    assert_raises(Lockbox::DecryptionError) do
      box.decrypt(ciphertext, associated_data: "bad")
    end
  end

  def test_xsalsa20
    box = Lockbox.new(key: random_key, algorithm: "xsalsa20")
    message = "it works!" * 10000
    ciphertext = box.encrypt(message)
    assert_equal message, box.decrypt(ciphertext)

    assert_equal Encoding::UTF_8, message.encoding
    assert_equal Encoding::BINARY, ciphertext.encoding
    assert_equal Encoding::BINARY, box.decrypt(ciphertext).encoding
  end

  def test_xchacha20
    box = Lockbox.new(key: random_key, algorithm: "xchacha20")
    message = "it works!" * 10000
    ciphertext = box.encrypt(message)
    assert_equal message, box.decrypt(ciphertext)

    assert_equal Encoding::UTF_8, message.encoding
    assert_equal Encoding::BINARY, ciphertext.encoding
    assert_equal Encoding::BINARY, box.decrypt(ciphertext).encoding
  end

  def test_xchacha20_associated_data
    box = Lockbox.new(key: random_key, algorithm: "xchacha20")
    message = "it works!"
    associated_data = "boom"
    ciphertext = box.encrypt(message, associated_data: associated_data)
    assert_equal message, box.decrypt(ciphertext, associated_data: associated_data)

    assert_raises(Lockbox::DecryptionError) do
      box.decrypt(ciphertext, associated_data: "bad")
    end
  end

  def test_hybrid
    key_pair = Lockbox.generate_key_pair

    box = Lockbox.new(algorithm: "hybrid", encryption_key: key_pair[:encryption_key])
    message = "it works!" * 10000
    ciphertext = box.encrypt(message)

    box = Lockbox.new(algorithm: "hybrid", decryption_key: key_pair[:decryption_key])
    assert_equal message, box.decrypt(ciphertext)
  end

  def test_hybrid_swapped
    key_pair = Lockbox.generate_key_pair

    box = Lockbox.new(algorithm: "hybrid", encryption_key: key_pair[:decryption_key])
    message = "it works!" * 10000
    ciphertext = box.encrypt(message)

    box = Lockbox.new(algorithm: "hybrid", decryption_key: key_pair[:encryption_key])
    assert_raises(Lockbox::DecryptionError) do
      box.decrypt(ciphertext)
    end
  end

  def test_bad_algorithm
    error = assert_raises(ArgumentError) do
      Lockbox.new(key: random_key, algorithm: "bad")
    end
    assert_includes error.message, "Unknown algorithm"
  end

  def test_bad_ciphertext
    box = Lockbox.new(key: random_key)

    assert_raises(Lockbox::DecryptionError) do
      box.decrypt("0")
    end

    assert_raises(Lockbox::DecryptionError) do
      box.decrypt("0"*16)
    end

    assert_raises(Lockbox::DecryptionError) do
      box.decrypt("0"*100)
    end
  end

  def test_bad_ciphertext_xchacha20
    box = Lockbox.new(key: random_key, algorithm: "xchacha20")

    assert_raises(Lockbox::DecryptionError) do
      box.decrypt("0")
    end

    assert_raises(Lockbox::DecryptionError) do
      box.decrypt("0"*16)
    end

    assert_raises(Lockbox::DecryptionError) do
      box.decrypt("0"*100)
    end
  end

  def test_rotation
    key = random_key
    box = Lockbox.new(key: key)
    message = "it works!"
    ciphertext = box.encrypt(message)
    new_box = Lockbox.new(key: random_key, previous_versions: [{key: key}])
    assert_equal message, new_box.decrypt(ciphertext)
  end

  def test_rotation_padding_only
    key = random_key
    box = Lockbox.new(key: key)
    message = "it works!"
    ciphertext = box.encrypt(message)
    new_box = Lockbox.new(key: key, padding: true, previous_versions: [{key: key}])
    assert_equal message, new_box.decrypt(ciphertext)

    # returning DecryptionError instead of PaddingError
    # is for end-user convenience, not for security
    assert_raises Lockbox::DecryptionError do
      Lockbox.new(key: key, padding: true).decrypt(ciphertext)
    end
  end

  def test_inspect
    box = Lockbox.new(key: random_key)
    refute_includes box.inspect, "key"
    refute_includes box.to_s, "key"
  end

  def test_xsalsa20_inspect
    box = Lockbox.new(key: random_key, algorithm: "xsalsa20")
    refute_includes box.inspect, "key"
    refute_includes box.to_s, "key"
  end

  def test_xchacha20_inspect
    box = Lockbox.new(key: random_key, algorithm: "xchacha20")
    refute_includes box.inspect, "key"
    refute_includes box.to_s, "key"
  end

  def test_decrypt_utf8
    box = Lockbox.new(key: random_key)
    message = "it works!"
    ciphertext = box.encrypt(message)
    ciphertext.force_encoding(Encoding::UTF_8)
    assert_equal message, box.decrypt(ciphertext)
  end

  def test_xsalsa20_decrypt_utf8
    box = Lockbox.new(key: random_key, algorithm: "xsalsa20")
    message = "it works!"
    ciphertext = box.encrypt(message)
    ciphertext.force_encoding(Encoding::UTF_8)
    assert_equal message, box.decrypt(ciphertext)
  end

  def test_xchacha20_decrypt_utf8
    box = Lockbox.new(key: random_key, algorithm: "xchacha20")
    message = "it works!"
    ciphertext = box.encrypt(message)
    ciphertext.force_encoding(Encoding::UTF_8)
    assert_equal message, box.decrypt(ciphertext)
  end

  def test_hex_key
    box = Lockbox.new(key: SecureRandom.hex(32))
    message = "it works!"
    ciphertext = box.encrypt(message)
    assert_equal message, box.decrypt(ciphertext)
  end

  def test_uppercase_hex_key
    box = Lockbox.new(key: SecureRandom.hex(32).upcase)
    message = "it works!"
    ciphertext = box.encrypt(message)
    assert_equal message, box.decrypt(ciphertext)
  end

  def test_xsalsa20_hex_key
    box = Lockbox.new(key: SecureRandom.hex(32), algorithm: "xsalsa20")
    message = "it works!"
    ciphertext = box.encrypt(message)
    assert_equal message, box.decrypt(ciphertext)
  end

  def test_xchacha20_hex_key
    box = Lockbox.new(key: SecureRandom.hex(32), algorithm: "xchacha20")
    message = "it works!"
    ciphertext = box.encrypt(message)
    assert_equal message, box.decrypt(ciphertext)
  end

  def test_encrypt_file
    box = Lockbox.new(key: SecureRandom.hex(32))
    message = "it works!"

    file = Tempfile.new
    file.write(message)
    file.rewind

    ciphertext = box.encrypt(file)
    assert_equal message, box.decrypt(ciphertext)
  end

  def test_decrypt_file
    box = Lockbox.new(key: SecureRandom.hex(32))
    message = "it works!"
    ciphertext = box.encrypt(message)

    file = Tempfile.new(encoding: Encoding::BINARY)
    file.write(ciphertext)
    file.rewind

    assert_equal message, box.decrypt(file)
  end

  def test_attribute_key
    key = Lockbox.attribute_key(table: "users", attribute: "license", master_key: "0"*64)
    assert_equal "d96ffa3fe916b3a9b57d084f5781e95748333b877e32e6399e387d3d75b238a1", key
  end

  def test_padding
    box = Lockbox.new(key: random_key, padding: true)
    message = "it works!"
    ciphertext = box.encrypt(message)
    # nonce + ciphertext + auth tag
    assert_equal 12 + 16 + 16, ciphertext.bytesize
    assert_equal message, box.decrypt(ciphertext)
  end

  def test_padding_integer
    box = Lockbox.new(key: random_key, padding: 13)
    message = "it works!"
    ciphertext = box.encrypt(message)
    # nonce + ciphertext + auth tag
    assert_equal 12 + 13 + 16, ciphertext.bytesize
    assert_equal message, box.decrypt(ciphertext)
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
    box = Lockbox.new(key: random_key)
    file = File.open("test/support/image.png", "rb")
    ciphertext_io = box.encrypt_io(file)
    assert_equal "image.png", ciphertext_io.original_filename
    assert_nil ciphertext_io.content_type

    file.rewind
    ciphertext_io.rewind
    refute_equal file.read, ciphertext_io.read

    file.rewind
    ciphertext_io.rewind
    assert_equal file.read, box.decrypt_io(ciphertext_io).read
  end

  private

  def random_key
    Lockbox.generate_key
  end
end
