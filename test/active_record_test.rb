require_relative "test_helper"

class ActiveRecordTest < Minitest::Test
  def test_symmetric
    email = "test@example.org"
    User.create!(email: email)
    user = User.last
    assert_equal user.email, email
  end

  def test_rotation
    email = "test@example.org"
    key = User.lockbox_attributes[:email][:previous_versions].first[:key]
    box = Lockbox.new(key: key)
    user = User.create!(email_ciphertext: Base64.strict_encode64(box.encrypt(email)))
    user = User.last
    assert_equal user.email, email
  end

  # ensure consistent with normal attributes
  def test_dirty
    original_name = "Test"
    original_email = "test@example.org"
    new_name = "New"
    new_email = "new@example.org"

    user = User.create!(name: original_name, email: original_email)
    user = User.last
    original_email_ciphertext = user.email_ciphertext

    assert !user.name_changed?
    assert !user.email_changed?

    assert_equal original_name, user.name_was
    # unsure if possible
    # assert_equal original_email, user.email_was

    # update
    user.name = new_name
    user.email = new_email

    # ensure changed
    assert user.name_changed?
    assert user.email_changed?

    # ensure was
    assert_equal original_name, user.name_was
    assert_equal original_email, user.email_was

    assert_equal [original_name, new_name], user.changes["name"]
    assert_equal [original_email, new_email], user.changes["email"]

    # ensure final value
    assert_equal new_name, user.name
    assert_equal new_email, user.email
    refute_equal original_email_ciphertext, user.email_ciphertext
  end

  def test_dirty_before_last_save
    skip if Rails.version < "5.1"

    original_name = "Test"
    original_email = "test@example.org"
    new_name = "New"
    new_email = "new@example.org"

    user = User.create!(name: original_name, email: original_email)
    user = User.last

    user.update!(name: new_name, email: new_email)

    # ensure updated
    assert_equal original_name, user.name_before_last_save
    assert_equal original_email, user.email_before_last_save
  end

  def test_dirty_bad_ciphertext
    user = User.create!(email_ciphertext: "bad")
    user.email = "test@example.org"
    assert_nil user.email_was
  end

  def test_inspect
    user = User.create!(email: "test@example.org")
    assert_nil user.serializable_hash["email"]
    assert_nil user.serializable_hash["email_ciphertext"]
    refute_includes user.inspect, "email"
  end

  def test_reload
    original_email = "test@example.org"
    new_email = "new@example.org"

    user = User.create!(email: original_email)
    user.email = new_email
    assert_equal new_email, user.email
    assert_equal new_email, user.attributes["email"]

    # reload
    user.reload

    # not loaded yet
    assert_nil user.attributes["email"]

    # loaded
    assert_equal original_email, user.email
    assert_equal original_email, user.attributes["email"]
  end

  def test_nil
    user = User.create!(email: "test@example.org")
    user.email = nil
    assert_nil user.email_ciphertext
  end

  def test_empty_string
    user = User.create!(email: "test@example.org")
    user.email = ""
    assert_equal "", user.email_ciphertext
  end

  def test_hybrid
    phone = "555-555-5555"
    User.create!(phone: phone)
    user = User.last
    assert_equal user.phone, phone
  end

  def test_validations_valid
    post = Post.new(title: "Hello World")
    assert post.valid?
    post.save!
    post = Post.last
    assert post.valid?
  end

  def test_validations_invalid
    post = Post.new
    assert !post.valid?
    assert_equal "Title can't be blank", post.errors.full_messages.first
  end

  def test_attribute_key_encrypted_column
    email = "test@example.org"
    user = User.create!(email: email)
    key = Lockbox.attribute_key(table: "users", attribute: "email_ciphertext")
    box = Lockbox.new(key: key)
    assert_equal email, box.decrypt(Base64.decode64(user.email_ciphertext))
  end

  def test_class_method
    email = "test@example.org"
    ciphertext = User.generate_email_ciphertext(email)
    key = Lockbox.attribute_key(table: "users", attribute: "email_ciphertext")
    box = Lockbox.new(key: key)
    assert_equal email, box.decrypt(Base64.decode64(ciphertext))
  end
end
