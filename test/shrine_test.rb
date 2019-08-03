require_relative "test_helper"

class ShrineTest < Minitest::Test
  def test_image
    path = "test/support/image.png"
    uploader = PassportUploader.new(:store)
    file = File.open(path)

    uploaded_file = uploader.upload(file)
    assert_equal "image/png", uploaded_file.mime_type
  end

  def test_mounted
    message = "hello world"

    file = Tempfile.new
    file.write(message)
    file.rewind

    user = User.create!(license: file)

    assert_equal message, user.license.read

    user = User.last
    assert_equal message, user.license.read
  end
end
