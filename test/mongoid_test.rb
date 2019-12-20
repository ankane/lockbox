require_relative "test_helper"

class MongoidTest < Minitest::Test
  def setup
    Person.delete_all
  end

  def teardown
    # very important!!
    # ensure no plaintext attributes exist
    Guard.all.each do |person|
      bad_keys = person.attributes.keys & %w(email phone ssn)
      assert_equal [], bad_keys, "Plaintext attribute exists"
    end
  end

  def test_symmetric
    email = "test@example.org"
    Person.create!(email: email)
    user = Person.last
    assert_equal email, user.email
  end

  def test_decrypt_after_destroy
    email = "test@example.org"
    User.create!(email: email)

    user = User.last
    user.destroy!

    user.email
  end

  def test_utf8
    email = "Łukasz"
    Person.create!(email: email)
    user = Person.last
    assert_equal email, user.email
  end

  def test_non_utf8
    email = "hi \255"
    Person.create!(email: email)
    user = Person.last
    assert_equal email, user.email
  end

  def test_rotation
    email = "test@example.org"
    key = Person.lockbox_attributes[:email][:previous_versions].first[:key]
    box = Lockbox.new(key: key)
    user = Person.create!(email_ciphertext: Base64.strict_encode64(box.encrypt(email)))
    user = Person.last
    assert_equal email, user.email
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

    user.email
    assert !user.name_changed?
    assert !user.email_changed?
    assert !user.changed?

    assert_equal original_name, user.name_was
    assert_equal original_email, user.email_was

    assert !user.name_changed?
    assert !user.email_changed?
    assert !user.changed?

    # update
    user.name = new_name
    user.email = new_email

    # ensure changed
    assert user.name_changed?
    assert user.email_changed?
    assert user.changed?

    # ensure was
    assert_equal original_name, user.name_was
    assert_equal original_email, user.email_was

    # ensure changes
    assert_equal [original_name, new_name], user.changes["name"]
    assert_equal [original_email, new_email], user.changes["email"]

    # ensure final value
    assert_equal new_name, user.name
    assert_equal new_email, user.email
    refute_equal original_email_ciphertext, user.email_ciphertext
  end

  def test_dirty_bad_ciphertext
    user = Person.create!(email_ciphertext: "bad")
    user.email = "test@example.org"
    assert user.email_changed?
  end

  def test_inspect
    user = Person.create!(email: "test@example.org")
    assert_nil user.serializable_hash["email"]
    assert_nil user.serializable_hash["email_ciphertext"]
    refute_includes user.inspect, "email"
  end

  def test_reload
    original_email = "test@example.org"
    new_email = "new@example.org"

    user = Person.create!(email: original_email)
    user.email = new_email
    assert_equal new_email, user.email

    # reload
    user.reload

    # loaded
    assert_equal original_email, user.email
  end

  def test_nil
    user = Person.create!(email: "test@example.org")
    user.email = nil
    assert_nil user.email_ciphertext
  end

  def test_empty_string
    user = Person.create!(email: "test@example.org")
    user.email = ""
    assert_equal "", user.email_ciphertext
  end

  def test_hybrid
    phone = "555-555-5555"
    Person.create!(phone: phone)
    user = Person.last
    assert_equal phone, user.phone
  end

  def test_validations_valid
    post = Comment.new(title: "Hello World")
    assert post.valid?
    post.save!
    post = Comment.last
    assert post.valid?
  end

  def test_validations_presence
    post = Comment.new
    assert !post.valid?
    assert_equal "Title can't be blank", post.errors.full_messages.first
  end

  def test_validations_length
    post = Comment.new(title: "Hi")
    assert !post.valid?
    assert_equal "Title is too short (minimum is 3 characters)", post.errors.full_messages.first
  end

  def test_encode
    skip # can't get Mongoid to handle binary data

    ssn = "123-45-6789"
    Person.create!(ssn: ssn)
    user = Person.last
    assert_equal user.ssn, ssn
    nonce_size = 12
    auth_tag_size = 16
    assert_equal nonce_size + ssn.bytesize + auth_tag_size, user.ssn_ciphertext.bytesize
  end

  def test_attribute_key_encrypted_column
    email = "test@example.org"
    user = Person.create!(email: email)
    key = Lockbox.attribute_key(table: "people", attribute: "email_ciphertext")
    box = Lockbox.new(key: key)
    assert_equal email, box.decrypt(Base64.decode64(user.email_ciphertext))
  end

  def test_class_method
    email = "test@example.org"
    ciphertext = Person.generate_email_ciphertext(email)
    key = Lockbox.attribute_key(table: "people", attribute: "email_ciphertext")
    box = Lockbox.new(key: key)
    assert_equal email, box.decrypt(Base64.decode64(ciphertext))
  end

  def test_migrate
    Dog.create!(name: "Hi", email: "test@example.org")
    Dog.update_all(name_ciphertext: nil, email_ciphertext: nil)
    Lockbox.migrate(Dog)
    dog = Dog.last
    assert_equal dog.name, dog.migrated_name
    assert_equal dog.email, dog.migrated_email
  end
end
