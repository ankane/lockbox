require_relative "test_helper"

class CarrierWaveTest < Minitest::Test
  def teardown
    @content = nil
  end

  def test_encrypt
    uploader = TextUploader.new
    uploader.store!(uploaded_file)

    assert_equal "#{content}!!", uploader.read
    refute_equal uploader.file.read, uploader.read

    assert_equal "#{content}!!..", uploader.thumb.read
    refute_equal uploader.thumb.file.read, uploader.thumb.read
  end

  def test_no_encrypt
    uploader = ImageUploader.new
    uploader.store!(uploaded_file)

    assert_equal "#{content}!!", uploader.read
    assert_equal uploader.file.read, uploader.read

    assert_equal "#{content}!!..", uploader.thumb.read
    assert_equal uploader.thumb.file.read, uploader.thumb.read
  end

  def test_rotate_encryption
    file = uploaded_file

    uploader = TextUploader.new
    uploader.store!(file)

    ciphertext = uploader.file.read
    thumb_ciphertext = uploader.thumb.file.read

    uploader = TextUploader.new
    uploader.retrieve_from_store!(File.basename(file.path))

    uploader.rotate_encryption!

    refute_equal ciphertext, uploader.file.read
    assert_equal "#{content}!!", uploader.read

    refute_equal thumb_ciphertext, uploader.thumb.file.read
    assert_equal "#{content}!!..", uploader.thumb.read

    assert uploader.enable_processing
  end

  def test_image
    uploader = AvatarUploader.new
    uploader.store!(image_file)

    assert_equal "image/png", uploader.content_type
    assert_equal image_content, uploader.read

    uploader = AvatarUploader.new
    uploader.retrieve_from_store!("image.png")

    assert_equal "image/png", uploader.content_type
    assert_equal image_content, uploader.read
  end

  def test_mounted
    skip if mongoid?

    user = User.create!(document: image_file)

    assert_equal image_content, user.document.read
    assert_equal "image/png", user.document.content_type
    refute_equal image_content, user.document.file.read

    user = User.last
    assert_equal image_content, user.document.read
    assert_equal "image/png", user.document.content_type
    refute_equal image_content, user.document.file.read
  end

  def test_mounted_many
    skip if mongoid?

    user = User.create!(documents: [image_file])

    assert_equal image_content, user.documents.first.read
    assert_equal "image/png", user.documents.first.content_type
    refute_equal image_content, user.documents.first.file.read

    user = User.last
    assert_equal image_content, user.documents.first.read
    assert_equal "image/png", user.documents.first.content_type
    refute_equal image_content, user.documents.first.file.read
  end

  def test_lockbox_options
    assert_equal({}, TextUploader.lockbox_options)
    assert_equal({}, AvatarUploader.lockbox_options)
    refute ImageUploader.respond_to?(:lockbox_options)
  end

  def content
    @content ||= "Test #{rand(1000)}"
  end

  def uploaded_file
    file = Tempfile.new
    file.write(content)
    file.rewind
    file
  end

  def image_content
    File.binread("test/support/image.png")
  end

  def image_file
    File.open("test/support/image.png", "rb")
  end
end
