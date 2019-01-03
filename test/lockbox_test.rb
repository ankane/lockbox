require_relative "test_helper"

class LockboxTest < Minitest::Test
  def test_aes_gcm
    box = Lockbox.new(key: random_key)
    message = "it works!" * 10000
    ciphertext = box.encrypt(message)
    assert_equal message, box.decrypt(ciphertext)

    assert_equal Encoding::UTF_8, message.encoding
    assert_equal Encoding::BINARY, ciphertext.encoding
    assert_equal Encoding::BINARY, box.decrypt(ciphertext).encoding
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

  def test_aes_gcm_associated_data
    box = Lockbox.new(key: random_key)
    message = "it works!"
    associated_data = "boom"
    ciphertext = box.encrypt(message, associated_data: associated_data)
    assert_equal message, box.decrypt(ciphertext, associated_data: associated_data)

    assert_raises(Lockbox::DecryptionError) do
      box.decrypt(ciphertext, associated_data: "bad")
    end
  end

  def test_xchacha20
    skip if travis?

    box = Lockbox.new(key: random_key, algorithm: "xchacha20")
    message = "it works!" * 10000
    ciphertext = box.encrypt(message)
    assert_equal message, box.decrypt(ciphertext)

    assert_equal Encoding::UTF_8, message.encoding
    assert_equal Encoding::BINARY, ciphertext.encoding
    assert_equal Encoding::BINARY, box.decrypt(ciphertext).encoding
  end

  def test_xchacha20_associated_data
    skip if travis?

    box = Lockbox.new(key: random_key, algorithm: "xchacha20")
    message = "it works!"
    associated_data = "boom"
    ciphertext = box.encrypt(message, associated_data: associated_data)
    assert_equal message, box.decrypt(ciphertext, associated_data: associated_data)

    assert_raises(Lockbox::DecryptionError) do
      box.decrypt(ciphertext, associated_data: "bad")
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
    skip if travis?

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

  def test_aes_gcm_inspect
    box = Lockbox.new(key: random_key)
    refute_includes box.inspect, "key"
    refute_includes box.to_s, "key"
  end

  def test_xchacha20_inspect
    skip if travis?

    box = Lockbox.new(key: random_key, algorithm: "xchacha20")
    refute_includes box.inspect, "key"
    refute_includes box.to_s, "key"
  end

  def test_aes_gcm_decrypt_utf8
    box = Lockbox.new(key: random_key)
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

  def test_aes_gcm_hex_key
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

  def test_xchacha20_hex_key
    skip if travis?

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

  private

  def random_key
    SecureRandom.random_bytes(32)
  end

  def travis?
    ENV["TRAVIS"]
  end
end
