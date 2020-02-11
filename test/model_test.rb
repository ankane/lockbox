require_relative "test_helper"

class ActiveRecordTest < Minitest::Test
  def setup
    User.delete_all
  end

  def teardown
    # very important!!
    # ensure no plaintext attributes exist
    assert_no_plaintext_attributes if mongoid?
  end

  def test_symmetric
    email = "test@example.org"
    User.create!(email: email)
    user = User.last
    assert_equal email, user.email
  end

  def test_decrypt_after_destroy
    email = "test@example.org"
    User.create!(email: email)

    user = User.last
    user.destroy!

    user.email
  end

  def test_was_bad_ciphertext
    user = User.create!(email_ciphertext: "bad")
    assert_raises Lockbox::DecryptionError do
      user.email_was
    end
  end

  def test_utf8
    email = "Łukasz"
    User.create!(email: email)
    user = User.last
    assert_equal email, user.email
  end

  def test_non_utf8
    email = "hi \255"
    User.create!(email: email)
    user = User.last
    assert_equal email, user.email
  end

  def test_rotation
    email = "test@example.org"
    key = User.lockbox_attributes[:email][:previous_versions].first[:key]
    box = Lockbox.new(key: key)
    user = User.create!(email_ciphertext: Base64.strict_encode64(box.encrypt(email)))
    user = User.last
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

    assert !user.name_changed?
    assert !user.email_changed?
    assert !user.changed?

    assert_nil user.name_change
    assert_nil user.email_change

    assert_equal original_name, user.name_was
    assert_equal original_email, user.email_was

    # in database
    if !mongoid? && ActiveRecord::VERSION::STRING >= "5.1"
      assert_equal original_name, user.name_in_database
      assert_equal original_email, user.email_in_database
    else
      assert !user.respond_to?(:name_in_database)
      assert !user.respond_to?(:email_in_database)
    end

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

    # ensure in database
    if !mongoid? && ActiveRecord::VERSION::STRING >= "5.1"
      assert_equal original_name, user.name_in_database
      assert_equal original_email, user.email_in_database
    else
      assert !user.respond_to?(:name_in_database)
      assert !user.respond_to?(:email_in_database)
    end

    # ensure changes
    assert_equal [original_name, new_name], user.name_change
    assert_equal [original_email, new_email], user.email_change
    assert_equal [original_name, new_name], user.changes["name"]
    assert_equal [original_email, new_email], user.changes["email"] unless mongoid?

    # ensure final value
    assert_equal new_name, user.name
    assert_equal new_email, user.email
    refute_equal original_email_ciphertext, user.email_ciphertext

    # save
    user.save!

    # ensure previous changes
    assert_equal [original_name, new_name], user.previous_changes["name"]
    assert_equal [original_email, new_email], user.previous_changes["email"] unless mongoid?
  end

  def test_dirty_before_last_save
    skip if mongoid? || ActiveRecord::VERSION::STRING < "5.1"

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

    if mongoid?
      assert user.email_changed?
    else
      assert_nil user.email_was
    end
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
    assert_equal new_email, user.attributes["email"] unless mongoid?

    # reload
    user.reload

    # not loaded yet
    assert_nil user.attributes["email"]

    # loaded
    assert_equal original_email, user.email
    assert_equal original_email, user.attributes["email"] unless mongoid?
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

  def test_attribute_present
    user = User.create!(name: "Test", email: "test@example.org")
    assert user.name?
    assert user.email?
    user = User.last
    assert user.name?
    assert user.email?

    user2 = User.create!(name: "", email: "")
    assert !user2.name?
    assert !user2.email?
  end

  def test_hybrid
    phone = "555-555-5555"
    User.create!(phone: phone)
    user = User.last
    assert_equal phone, user.phone
  end

  def test_validations_valid
    post = Post.new(title: "Hello World")
    assert post.valid?
    post.save!
    post = Post.last
    assert post.valid?
  end

  def test_validations_presence
    post = Post.new
    assert !post.valid?
    assert_equal "Title can't be blank", post.errors.full_messages.first
  end

  def test_validations_length
    post = Post.new(title: "Hi")
    assert !post.valid?
    assert_equal "Title is too short (minimum is 3 characters)", post.errors.full_messages.first
  end

  def test_encode
    skip "Can't get Mongoid to handle binary data" if mongoid?

    ssn = "123-45-6789"
    User.create!(ssn: ssn)
    user = User.last
    assert_equal user.ssn, ssn
    nonce_size = 12
    auth_tag_size = 16
    assert_equal nonce_size + ssn.bytesize + auth_tag_size, user.ssn_ciphertext.bytesize
  end

  def test_attribute_key_encrypted_column
    email = "test@example.org"
    user = User.create!(email: email)
    key = Lockbox.attribute_key(table: "users", attribute: "email_ciphertext")
    box = Lockbox.new(key: key, encode: true)
    assert_equal email, box.decrypt(user.email_ciphertext)
  end

  def test_class_method
    email = "test@example.org"
    ciphertext = User.generate_email_ciphertext(email)
    key = Lockbox.attribute_key(table: "users", attribute: "email_ciphertext")
    box = Lockbox.new(key: key, encode: true)
    assert_equal email, box.decrypt(ciphertext)
  end

  def test_padding
    user = User.create!(city: "New York")
    assert_equal 12 + 16 + 16, Base64.decode64(user.city_ciphertext).bytesize
  end

  def test_padding_empty_string
    user = User.create!(city: "")
    assert_equal 12 + 16 + 16, Base64.decode64(user.city_ciphertext).bytesize
  end

  def test_padding_invalid
    user = User.create!(city_ciphertext: "")
    assert_raises(Lockbox::DecryptionError) do
      user.city
    end
  end

  def test_migrate
    Robot.create!(name: "Hi", email: "test@example.org")
    Robot.update_all(name_ciphertext: nil, email_ciphertext: nil)
    Lockbox.migrate(Robot)
    robot = Robot.last
    assert_equal robot.name, robot.migrated_name
    assert_equal robot.email, robot.migrated_email
  end

  def test_migrate_relation
    skip "waiting for 0.4.0"

    Robot.create!(name: "Hi")
    Robot.create!(name: "Bye")
    Robot.update_all(name_ciphertext: nil)
    Lockbox.migrate(Robot.order(:id).limit(1))
    robot1, robot2 = Robot.order(:id).to_a
    assert_equal robot1.name, robot1.migrated_name
    assert_nil robot2.migrated_name
  end

  def test_bad_master_key
    previous_value = Lockbox.master_key
    begin
      Lockbox.master_key = "bad"
      assert_raises(Lockbox::Error) do
        User.create!(email: "test@example.org")
      end
    ensure
      Lockbox.master_key = previous_value
    end
  end

  def test_restore_reset
    original_name = "Test"
    original_email = "test@example.org"
    new_name = "New"
    new_email = "new@example.org"

    user = User.create!(name: original_name, email: original_email)
    user.name = new_name
    user.email = new_email

    if mongoid?
      assert_equal original_name, user.reset_name!
      assert_equal original_email, user.reset_email!
    else
      user.restore_name!
      user.restore_email!
    end

    assert_equal original_name, user.name
    assert_equal original_email, user.email
  end

  def test_reset_to_default
    skip unless mongoid?

    original_name = "Test"
    original_email = "test@example.org"
    new_name = "New"
    new_email = "new@example.org"

    user = User.create!(name: original_name, email: original_email)
    user.name = new_name
    user.email = new_email

    assert_nil user.reset_name_to_default!
    assert_nil user.reset_email_to_default!

    assert_nil user.name
    assert_nil user.email
  end

  def test_plaintext_not_saved
    skip unless mongoid?

    user = User.create!(email: "test@example.org")

    assert_no_plaintext_attributes

    user = User.last
    user.email = "new@example.org"
    user.save!

    assert_no_plaintext_attributes

    user = User.last
    user.email
    user.email = "new2@example.org"
    user.save!

    assert_no_plaintext_attributes
  end

  private

  def assert_no_plaintext_attributes
    Guard.all.each do |user|
      bad_keys = user.attributes.keys & %w(email phone ssn)
      assert_equal [], bad_keys, "Plaintext attribute exists"
    end
  end
end
