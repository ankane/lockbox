require_relative "test_helper"

class ActiveStorageTest < Minitest::Test
  def setup
    skip unless defined?(ActiveStorage)

    ActiveStorage::Attachment.delete_all
    ActiveStorage::Blob.delete_all
  end

  def teardown
    @content = nil
    @contents = nil
  end

  def test_encrypt_one
    user = User.create!(avatar: attachment)
    assert_equal content, user.avatar.download
    refute_equal content, user.avatar.blob.download

    user = User.last
    assert_equal content, user.avatar.download
    refute_equal content, user.avatar.blob.download
    assert user.avatar.metadata["encrypted"]
  end

  def test_encrypt_uploaded_file
    user = User.create!(avatar: uploaded_file)
    assert_equal content, user.avatar.download
    refute_equal content, user.avatar.blob.download

    user = User.last
    assert_equal content, user.avatar.download
    refute_equal content, user.avatar.blob.download
    assert user.avatar.metadata["encrypted"]
  end

  def test_encrypt_blank_one
    user = User.create!(avatar: attachment(""))
    assert_equal "", user.avatar.download
    refute_equal "", user.avatar.blob.download

    user = User.last
    assert_equal "", user.avatar.download
    refute_equal "", user.avatar.blob.download
  end

  def test_encrypt_blank_uploaded_file
    user = User.create!(avatar: uploaded_file(""))
    assert_equal "", user.avatar.download
    refute_equal "", user.avatar.blob.download

    user = User.last
    assert_equal "", user.avatar.download
    refute_equal "", user.avatar.blob.download
  end

  def test_encrypt_blob
    user = User.create!(avatar: attachment)

    if ActiveStorage::VERSION::MAJOR >= 6
      # blobs are just attached, not (re)encrypted
      User.create!(avatar: user.avatar.blob)
    else
      error = assert_raises(ArgumentError) do
        User.create!(avatar: user.avatar.blob)
      end
      assert_match "Could not find or build blob: expected attachable", error.message
    end
  end

  def test_encrypt_unencrypted_blob
    unencrypted_blob = User.create!(image: attachment).image.blob

    if ActiveStorage::VERSION::MAJOR >= 6
      # attaches but fails to decrypt
      user = User.create!(avatar: unencrypted_blob)
      assert_raises(Lockbox::DecryptionError) do
        user.avatar.download
      end
    else
      # fails to attach
      error = assert_raises(ArgumentError) do
        User.create!(avatar: unencrypted_blob)
      end
      assert_match "Could not find or build blob: expected attachable", error.message
    end
  end

  def test_encrypt_unsupported
    # silently fails with Active Storage 5.2
    if ActiveStorage::VERSION::MAJOR >= 6
      error = assert_raises(ArgumentError) do
        User.create!(image: 123)
      end
      assert_equal "Could not find or build blob: expected attachable, got 123", error.message
    end

    error = assert_raises(ArgumentError) do
      User.create!(avatar: 123)
    end
    assert_equal "Could not find or build blob: expected attachable, got 123", error.message
  end

  def test_encrypt_attach
    user = User.create!
    user.avatar.attach(uploaded_file)
    assert_equal content, user.avatar.download
    refute_equal content, user.avatar.blob.download

    user = User.last
    assert_equal content, user.avatar.download
    refute_equal content, user.avatar.blob.download
  end

  def test_encrypt_many
    user = User.create!(avatars: attachments)
    assert_equal contents, user.avatars.map(&:download)
    refute_equal contents, user.avatars.map { |a| a.blob.download }

    user = User.last
    assert_equal contents, user.avatars.map(&:download)
    refute_equal contents, user.avatars.map { |a| a.blob.download }
    assert user.avatars.all? { |a| a.metadata["encrypted"] }
  end

  def test_encrypt_many_attach
    user = User.create!
    attachments.each do |attachment|
      user.avatars.attach(attachment)
    end
    assert_equal contents, user.avatars.map(&:download)
    refute_equal contents, user.avatars.map { |a| a.blob.download }

    user = User.last
    assert_equal contents, user.avatars.map(&:download)
    refute_equal contents, user.avatars.map { |a| a.blob.download }
    assert user.avatars.all? { |a| a.metadata["encrypted"] }
  end

  def test_no_encrypt_one
    user = User.create!(image: attachment)

    assert_equal content, user.image.download
    assert_equal content, user.image.blob.download

    user = User.last
    assert_equal content, user.image.download
    assert_equal content, user.image.blob.download
  end

  def test_no_encrypt_one_attach
    user = User.create!
    user.image.attach(attachment)

    assert_equal content, user.image.download
    assert_equal content, user.image.blob.download

    user = User.last
    assert_equal content, user.image.download
    assert_equal content, user.image.blob.download
  end

  def test_no_encrypt_many
    user = User.create!(images: attachments)

    assert_equal contents, user.images.map(&:download)
    assert_equal contents, user.images.map { |a| a.blob.download }

    user = User.last
    assert_equal contents, user.images.map(&:download)
    assert_equal contents, user.images.map { |a| a.blob.download }
  end

  # not yet supported
  # tries to transform the encrypted file
  def test_encrypt_variant
    path = "test/support/image.png"
    User.create!(avatar: {io: File.open(path), filename: "image.png", content_type: "image/png"})

    user = User.last
    error = assert_raises(Lockbox::Error) do
      user.avatar.variant(resize: "500x500").processed
    end
    assert_equal "Variant not supported for encrypted files", error.message
  end

  def test_no_encrypt_variant
    path = "test/support/image.png"
    User.create!(image: {io: File.open(path), filename: "image.png", content_type: "image/png"})

    user = User.last
    user.image.variant(resize: "500x500").processed
  end

  # not yet supported
  # tries to transform the encrypted file
  # succeeds, but unreadable
  def test_encrypt_preview
    path = "test/support/doc.pdf"
    User.create!(avatar: {io: File.open(path), filename: "doc.pdf", content_type: "application/pdf"})

    user = User.last
    error = assert_raises(Lockbox::Error) do
      user.avatar.preview(resize: "500x500").processed.blob.download
    end
    assert_equal "Preview not supported for encrypted files", error.message
  end

  def test_no_encrypt_preview
    skip "Requires Poppler or muPDF" unless ENV["TRAVIS"]

    path = "test/support/doc.pdf"
    User.create!(image: {io: File.open(path), filename: "doc.pdf", content_type: "application/pdf"})

    user = User.last
    contents = user.image.preview(resize: "500x500").processed.blob.download
    assert_match "%PDF-1.3", contents
  end

  def test_rotate_encryption_one
    message = "hello world"
    filename = "test.txt"
    content_type = "image/png"
    user = User.create!(avatar: {io: StringIO.new(message), filename: filename, content_type: content_type})
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
    user = User.create!(avatars: attachments)
    blobs = user.avatars.map(&:blob)

    user.avatars.rotate_encryption!
    new_blobs = user.avatars.map(&:blob)

    refute_equal blobs, new_blobs
    assert_equal blobs.size, new_blobs.size
    assert_equal contents, user.avatars.map(&:download)
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
      user = User.create!(avatar: {io: File.open(path), filename: "image.png", content_type: "image/png"})

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
    post = Post.create!(title: "123", photo: attachment)
    assert_equal content, post.photo.download
    assert_equal content, post.photo.blob.download
  end

  def test_open
    skip if ActiveStorage::VERSION::MAJOR < 6

    user = User.create!(avatar: attachment)
    user.avatar.open do |f|
      assert_equal content, f.read
    end
  end

  def test_open_blank
    skip if ActiveStorage::VERSION::MAJOR < 6

    user = User.create!(avatar: attachment(""))
    user.avatar.open do |f|
      assert_equal "", f.read
    end
  end

  def test_metadata
    user = User.create!

    user.image.attach(attachment.merge(metadata: {"hello" => true}))
    assert user.image.metadata["hello"]

    user.avatar.attach(attachment.merge(metadata: {"hello" => true}))
    assert user.avatar.metadata["hello"]
  end

  def test_migrating
    Comment.destroy_all

    comment = Comment.create!(image: attachment)

    assert_equal content, comment.image.download
    assert_equal content, comment.image.blob.download
    assert_nil comment.image.metadata["encrypted"]

    with_migrating(:image) do
      comment = Comment.last
      comment.image.attach(attachment)
      assert_equal content, comment.image.download
      refute_equal content, comment.image.blob.download
      assert comment.image.metadata["encrypted"]
    end

    assert_equal 1, ActiveStorage::Blob.count
  end

  def test_migrate_one
    Comment.destroy_all

    comment = Comment.create!(image: attachment)

    assert_equal content, comment.image.download
    assert_equal content, comment.image.blob.download
    assert_nil comment.image.metadata["encrypted"]

    with_migrating(:image) do
      Lockbox.migrate(Comment)

      comment = Comment.last
      assert_equal content, comment.image.download
      refute_equal content, comment.image.blob.download
      assert comment.image.metadata["encrypted"]

      comment = Comment.last
      comment.image.attach(attachment)
      assert_equal content, comment.image.download
      refute_equal content, comment.image.blob.download
      assert comment.image.metadata["encrypted"]
    end

    assert_equal 1, ActiveStorage::Blob.count
  end

  def test_migrate_many
    Comment.destroy_all

    comment = Comment.create!(images: attachments)
    assert_equal contents, comment.images.map(&:download)
    assert_equal contents, comment.images.map { |image| image.blob.download }
    assert comment.images.all? { |image| image.metadata["encrypted"].nil? }

    with_migrating(:images) do
      Lockbox.migrate(Comment)

      comment = Comment.last
      assert_equal 3, comment.images.size
      assert_equal contents, comment.images.map(&:download)
      refute_equal contents, comment.images.map { |image| image.blob.download }
      assert comment.images.all? { |image| image.metadata["encrypted"] }

      comment = Comment.last
      new_message = "Test 4"
      comment.images.attach(attachment(new_message))
      assert_equal new_message, comment.images.last.download
      refute_equal new_message, comment.images.last.blob.download
      assert comment.images.last.metadata["encrypted"]
    end

    assert_equal 4, ActiveStorage::Blob.count
  end

  def test_migrate_one_none_attached
    Comment.destroy_all

    Comment.create!

    with_migrating(:image) do
      Lockbox.migrate(Comment)
    end
  end

  def test_migrate_many_none_attached
    Comment.destroy_all

    Comment.create!

    with_migrating(:images) do
      Lockbox.migrate(Comment)
    end
  end

  def test_migrate_relation
    Comment.destroy_all

    comment = Comment.create!(image: attachment)
    comment2 = Comment.create!(image: attachment)

    assert_nil comment.image.metadata["encrypted"]
    assert_nil comment2.image.metadata["encrypted"]

    with_migrating(:image) do
      Lockbox.migrate(Comment.where(id: comment.id))

      comment.reload
      comment2.reload

      assert_equal content, comment.image.download
      refute_equal content, comment.image.blob.download
      assert comment.image.metadata["encrypted"]

      assert_equal content, comment2.image.download
      assert_equal content, comment2.image.blob.download
      assert_nil comment2.image.metadata["encrypted"]
    end

    assert_equal 2, ActiveStorage::Blob.count
  end

  def with_migrating(name)
    Comment.instance_variable_get(:@lockbox_attachments)[name] = {migrating: true}
    yield
  ensure
    Comment.instance_variable_get(:@lockbox_attachments).delete(name)
  end

  def content
    @content ||= "Test #{rand(1000)}"
  end

  def contents
    @contents ||= 3.times.map { "Test #{rand(1000)}" }
  end

  def attachment(content = nil)
    content ||= self.content
    {io: StringIO.new(content), filename: "#{content.downcase.gsub(" ", "-")}.txt"}
  end

  def attachments
    contents.map { |c| attachment(c) }
  end

  def uploaded_file(content = nil)
    content ||= self.content
    file = Tempfile.new
    file.write(content)
    file.rewind
    ActionDispatch::Http::UploadedFile.new(
      filename: "#{content.downcase.gsub(" ", "-")}.txt",
      tempfile: file
    )
  end
end
