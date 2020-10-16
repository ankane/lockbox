require_relative "test_helper"

class ShrineTest < Minitest::Test
  def test_works
    lockbox = Lockbox.new(key: Lockbox.generate_key)
    uploaded_file = PhotoUploader.upload(lockbox.encrypt_io(image_file), :store)
    assert_equal image_content, lockbox.decrypt(uploaded_file.read)
  end

  def test_model
    lockbox = Lockbox.new(key: Lockbox.generate_key)
    user = User.create!(photo: lockbox.encrypt_io(image_file))
    assert_equal image_content, lockbox.decrypt(user.photo.read)
  end

  def image_content
    File.binread("test/support/image.png")
  end

  def image_file
    File.open("test/support/image.png", "rb")
  end
end
