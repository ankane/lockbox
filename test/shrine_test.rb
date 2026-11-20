require_relative "test_helper"

class ShrineTest < Minitest::Test
  def setup
    @image_file = nil
  end

  def test_works
    options = {key: Lockbox.generate_key}
    uploaded_file = PhotoUploader.upload(Lockbox.encrypt_io(image_file, **options), :store)
    data = Lockbox.decrypt(uploaded_file.read, **options)
    assert_equal image_content, data
    assert_equal "image/png", Shrine.mime_type(StringIO.new(data))
  end

  def test_model
    options = {key: Lockbox.generate_key}

    user = User.create!(photo: Lockbox.encrypt_io(image_file, **options))
    data = Lockbox.decrypt(user.photo.read, **options)
    assert_equal image_content, data
    assert_equal "image/png", Shrine.mime_type(StringIO.new(data))

    user = User.last
    data = Lockbox.decrypt(user.photo.read, **options)
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
