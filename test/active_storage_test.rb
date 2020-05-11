require_relative "test_helper"

class ActiveStorageTest < Minitest::Test
  def setup
    skip unless defined?(ActiveStorage)
  end

  def test_encrypt_one
    message = "hello world"
    user = User.create!
    user.avatar.attach(io: StringIO.new(message), filename: "test.txt")
    assert_equal message, user.avatar.download
    refute_equal message, user.avatar.blob.download

    user = User.last
    assert_equal message, user.avatar.download

    # only set when migrating for now
    # assert user.avatar.blob.metadata["encrypted"]
  end

  def test_encrypt_uploaded_file
    message = "hello world"
    user = User.create!

    file = Tempfile.new
    file.write(message)
    file.rewind
    user.avatar.attach(ActionDispatch::Http::UploadedFile.new(filename: "test.txt", tempfile: file))

    refute_equal message, user.avatar.blob.download
    assert_equal message, user.avatar.download

    user = User.last
    assert_equal message, user.avatar.download
  end

  def test_encrypt_blob
    message = "hello world"
    user = User.create!
    user.avatar.attach(io: StringIO.new(message), filename: "test.txt")

    user2 = User.create!

    if ActiveStorage::VERSION::MAJOR >= 6
      # blobs are just attached, not (re)encrypted
      assert user2.avatar.attach(user.avatar.blob)
    else
      assert_raises NotImplementedError do
        user2.avatar.attach(user.avatar.blob)
      end
    end
  end

  def test_encrypt_string
    message = "hello world"
    user = User.create!

    assert_raises NotImplementedError do
      user.avatar.attach(message)
    end
  end

  def test_encrypt_create
    message = "hello world"

    file = Tempfile.new
    file.write(message)
    file.rewind
    user = User.create!(avatar: ActionDispatch::Http::UploadedFile.new(filename: "test.txt", tempfile: file))

    refute_equal message, user.avatar.blob.download
    assert_equal message, user.avatar.download

    user = User.last
    assert_equal message, user.avatar.download
  end

  def test_encrypt_many
    messages = ["hello world", "goodbye moon"]
    user = User.create!
    messages.each do |message|
      user.avatars.attach(io: StringIO.new(message), filename: "#{message.gsub(" ", "_")}.txt")
    end
    assert_equal messages, user.avatars.map(&:download)
    refute_equal messages, user.avatars.map { |a| a.blob.download }

    user = User.last
    assert_equal messages, user.avatars.map(&:download)

    # only set when migrating for now
    # assert user.avatars.all? { |a| a.blob.metadata["encrypted"] }
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
    # run many times to make sure content type is detected correctly
    iterations = ENV["CI"] ? 1000 : 1
    iterations.times do
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

  def test_has_one_attached_with_no_encrypted_attachments
    message = "hello world"
    post = Post.create!(title: "123")
    post.photo.attach(io: StringIO.new(message), filename: "test.txt")
    assert_equal message, post.photo.download
    assert_equal message, post.photo.blob.download
  end

  def test_open
    skip if ActiveStorage::VERSION::MAJOR < 6

    path = "test/support/image.png"
    user = User.create!
    user.avatar.attach(io: File.open(path), filename: "image.png", content_type: "image/png")

    user.avatar.open do |f|
      assert_equal File.binread(path), f.read
    end
  end

  def test_migrate_one
    Comment.destroy_all

    message = "hello world"

    comment = Comment.create!
    comment.image.attach(io: StringIO.new(message), filename: "test.txt")

    assert_equal message, comment.image.download
    assert_equal message, comment.image.blob.download
    assert_nil comment.image.metadata["encrypted"]

    with_migrating(:image) do
      Lockbox.migrate(Comment)

      comment = Comment.last
      assert_equal message, comment.image.download
      refute_equal message, comment.image.blob.download
      assert comment.image.metadata["encrypted"]

      comment = Comment.last
      comment.image.attach(io: StringIO.new(message), filename: "test.txt")
      assert_equal message, comment.image.download
      refute_equal message, comment.image.blob.download
      assert comment.image.metadata["encrypted"]
    end
  end

  def test_migrate_many
    Comment.destroy_all

    messages = ["Test 1", "Test 2", "Test 3"]

    comment = Comment.create!
    messages.each do |message|
      comment.images.attach(io: StringIO.new(message), filename: "test.txt")
    end

    assert_equal messages, comment.images.map(&:download).sort
    assert_equal messages, comment.images.blobs.map(&:download).sort
    assert_nil comment.images.first.metadata["encrypted"]

    with_migrating(:images) do
      Lockbox.migrate(Comment)

      comment = Comment.last
      assert_equal 3, comment.images.size
      assert_equal messages, comment.images.map(&:download).sort
      refute_equal messages, comment.images.blobs.map(&:download).sort
      assert comment.images.all? { |image| image.metadata["encrypted"] }

      comment = Comment.last
      new_message = "Test 4"
      comment.images.attach(io: StringIO.new(new_message), filename: "test.txt")
      assert_equal new_message, comment.images.last.download
      refute_equal new_message, comment.images.last.blob.download
      assert comment.images.last.metadata["encrypted"]
    end
  end

  def test_migrate_one_none_attached
    Comment.destroy_all

    comment = Comment.create!

    with_migrating(:image) do
      Lockbox.migrate(Comment)
    end
  end

  def test_migrate_many_none_attached
    Comment.destroy_all

    comment = Comment.create!

    with_migrating(:images) do
      Lockbox.migrate(Comment)
    end
  end

  def test_migrate_relation
    Comment.destroy_all

    message = "hello world"

    comment = Comment.create!
    comment.image.attach(io: StringIO.new(message), filename: "test.txt")

    comment2 = Comment.create!
    comment2.image.attach(io: StringIO.new(message), filename: "test.txt")

    assert_nil comment.image.metadata["encrypted"]
    assert_nil comment2.image.metadata["encrypted"]

    with_migrating(:image) do
      Lockbox.migrate(Comment.where(id: comment.id))

      comment.reload
      comment2.reload

      assert_equal message, comment.image.download
      refute_equal message, comment.image.blob.download
      assert comment.image.metadata["encrypted"]

      assert_equal message, comment2.image.download
      assert_equal message, comment2.image.blob.download
      assert_nil comment2.image.metadata["encrypted"]
    end
  end

  def with_migrating(name)
    Comment.instance_variable_get(:@lockbox_attachments)[name] = {migrating: true}
    yield
  ensure
    Comment.instance_variable_get(:@lockbox_attachments).delete(name)
  end
end
