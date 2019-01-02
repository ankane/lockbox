require_relative "test_helper"

class ActiveStorageTest < Minitest::Test
  def test_encrypt_one
    message = "hello world"
    user = User.create!
    user.avatar.attach(io: StringIO.new(message), filename: "test.txt")
    assert_equal message, user.avatar.download
    refute_equal message, user.avatar.blob.download

    user = User.last
    assert_equal message, user.avatar.download
  end

  def test_encrypt_uploaded_file
    message = "hello world"
    user = User.create!

    file = Tempfile.new
    file.write(message)
    file.rewind
    user.avatar.attach(ActionDispatch::Http::UploadedFile.new(filename: "test.txt", tempfile: file))

    assert_equal message, user.avatar.download
    refute_equal message, user.avatar.blob.download

    user = User.last
    assert_equal message, user.avatar.download
  end

  def test_encrypt_create
    message = "hello world"

    file = Tempfile.new
    file.write(message)
    file.rewind
    user = User.create!(avatar: ActionDispatch::Http::UploadedFile.new(filename: "test.txt", tempfile: file))

    assert_equal message, user.avatar.download
    refute_equal message, user.avatar.blob.download

    user = User.last
    assert_equal message, user.avatar.download
  end

  def test_encrypt_many
    messages = ["hello world", "goodbye moon"]
    user = User.create!
    messages.each do |message|
      user.avatars.attach(io: StringIO.new(message), filename: "test.txt")
    end
    assert_equal messages, user.avatars.map(&:download)
    refute_equal messages, user.avatars.map { |a| a.blob.download }

    user = User.last
    assert_equal messages, user.avatars.map(&:download)
  end

  def test_no_encrypt_one
    message = "hello world"
    user = User.create!
    user.image.attach(io: StringIO.new(message), filename: "test.txt")
    assert_equal message, user.image.download
    assert_equal message, user.image.blob.download

    user = User.last
    assert_equal message, user.image.download
  end

  def test_no_encrypt_many
    messages = ["hello world", "goodbye moon"]
    user = User.create!
    messages.each do |message|
      user.images.attach(io: StringIO.new(message), filename: "test.txt")
    end
    assert_equal messages, user.images.map(&:download)
    assert_equal messages, user.images.map { |a| a.blob.download }

    user = User.last
    assert_equal messages, user.images.map(&:download)
  end

  def test_rotate_encryption_one
    message = "hello world"
    filename = "test.txt"
    content_type = "image/png"
    user = User.create!
    user.avatar.attach(io: StringIO.new(message), filename: filename, content_type: content_type)
    blob = user.avatar.attachment.blob
    user.avatar.rotate_encryption!

    assert_equal content_type, user.avatar.content_type
    assert_equal filename, user.avatar.filename.to_s
    refute_equal blob, user.avatar.blob
    assert_equal message, user.avatar.download

    user = User.last
    assert_equal content_type, user.avatar.content_type
    assert_equal filename, user.avatar.filename.to_s
    refute_equal blob, user.avatar.blob
    assert_equal message, user.avatar.download
  end

  def test_rotate_encryption_many
    messages = ["hello world", "goodbye moon"]
    user = User.create!
    messages.each do |message|
      user.avatars.attach(io: StringIO.new(message), filename: "test.txt")
    end
    blobs = user.avatars.map(&:blob)

    user.avatars.rotate_encryption!
    new_blobs = user.avatars.map(&:blob)

    refute_equal blobs, new_blobs
    assert_equal blobs.size, new_blobs.size
    assert_equal messages, user.avatars.map(&:download)
  end

  def test_rotate_encryption_not_attached
    user = User.create!
    user.avatar.rotate_encryption!
    refute user.avatar.attached?
  end

  def test_image
    path = "test/support/image.png"
    user = User.create!
    user.avatar.attach(io: File.open(path), filename: "image.png", content_type: "image/png")

    assert_equal "image/png", user.avatar.content_type
    assert_equal "image.png", user.avatar.filename.to_s
    assert_equal File.binread(path), user.avatar.download

    user = User.last
    assert_equal "image/png", user.avatar.content_type
    assert_equal "image.png", user.avatar.filename.to_s
    assert_equal File.binread(path), user.avatar.download
  end
end
