require_relative "test_helper"

class CarrierWaveTest < Minitest::Test
  def test_encrypt
    message = "hello world"

    uploader = TextUploader.new
    file = Tempfile.new
    file.write(message)
    uploader.store!(file)

    assert_equal "#{message}!!", uploader.read
    refute_equal uploader.file.read, uploader.read

    assert_equal "#{message}!!..", uploader.thumb.read
    refute_equal uploader.thumb.file.read, uploader.read
  end

  def test_no_encrypt
    message = "hello world"

    uploader = ImageUploader.new
    file = Tempfile.new
    file.write(message)
    uploader.store!(file)

    assert_equal message, uploader.read
    assert_equal uploader.file.read, uploader.read
  end

  def test_rotate_encryption
    message = "hello world"

    uploader = TextUploader.new
    file = Tempfile.new
    file.write(message)
    uploader.store!(file)

    ciphertext = uploader.file.read
    thumb_ciphertext = uploader.thumb.file.read

    uploader = TextUploader.new
    uploader.retrieve_from_store!(File.basename(file.path))

    uploader.rotate_encryption!

    refute_equal ciphertext, uploader.file.read
    assert_equal "#{message}!!", uploader.read

    refute_equal thumb_ciphertext, uploader.thumb.file.read
    assert_equal "#{message}!!..", uploader.thumb.read

    assert uploader.enable_processing
  end

  def test_image
    path = "test/support/image.png"
    uploader = AvatarUploader.new
    uploader.store!(File.open(path))

    assert_equal "image/png", uploader.content_type
    assert_equal File.binread(path), uploader.read

    uploader = AvatarUploader.new
    uploader.retrieve_from_store!("image.png")

    # incorrect mime type in CarrierWave 2.0
    # assert_equal "image/png", uploader.content_type
    assert_equal File.binread(path), uploader.read
  end

  def test_mounted
    message = "hello world"

    file = Tempfile.new
    file.write(message)

    user = User.create!(document: file)

    assert_equal message, user.document.read
    refute_equal message, user.document.file.read

    user = User.last
    assert_equal message, user.document.read
  end
end
