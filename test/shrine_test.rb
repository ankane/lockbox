require_relative "test_helper"

class ShrineTest < Minitest::Test
  def setup
    @image_file = nil
  end

  def test_works
    lockbox = Lockbox.new(key: Lockbox.generate_key)
    uploaded_file = PhotoUploader.upload(lockbox.encrypt_io(image_file), :store)
    data = lockbox.decrypt(uploaded_file.read)
    assert_equal image_content, data
    assert_equal "image/png", Shrine.mime_type(StringIO.new(data))
  end

  def test_model
    lockbox = Lockbox.new(key: Lockbox.generate_key)

    user = User.create!(photo: lockbox.encrypt_io(image_file))
    data = lockbox.decrypt(user.photo.read)
    assert_equal image_content, data
    assert_equal "image/png", Shrine.mime_type(StringIO.new(data))

    user = User.last
    data = lockbox.decrypt(user.photo.read)
    assert_equal image_content, data
    assert_equal "image/png", Shrine.mime_type(StringIO.new(data))
  end

  def image_content
    File.binread("test/support/image.png")
  end

  def image_file
    @image_file ||= File.open("test/support/image.png", "rb")
  end
end
