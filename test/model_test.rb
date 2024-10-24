require_relative "test_helper"

class ModelTest < Minitest::Test
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

  # ensure consistent with normal attributes
  # https://github.com/rails/rails/blob/master/activemodel/lib/active_model/dirty.rb
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
    if !mongoid?
      assert_equal original_name, user.name_in_database
      assert_equal original_email, user.email_in_database
    else
      assert !user.respond_to?(:name_in_database)
      assert !user.respond_to?(:email_in_database)
    end

    assert !user.name_changed?
    assert !user.email_changed?
    assert !user.changed?
    assert_equal [], user.changed

    if !mongoid?
      assert !user.will_save_change_to_name?
      assert !user.will_save_change_to_email?
    end

    # update
    user.name = new_name
    user.email = new_email

    if !mongoid?
      assert user.will_save_change_to_name?
      assert user.will_save_change_to_email?
    end

    # ensure changed
    assert user.name_changed?
    assert user.email_changed?
    assert user.changed?
    if mongoid?
      assert_equal ["email_ciphertext", "name"], user.changed.sort
    else
      assert_equal ["email", "email_ciphertext", "name"], user.changed.sort
    end

    # ensure was
    assert_equal original_name, user.name_was
    assert_equal original_email, user.email_was

    # ensure in database
    if !mongoid?
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
    skip if mongoid?

    original_name = "Test"
    original_email = "test@example.org"
    new_name = "New"
    new_email = "new@example.org"

    user = User.create!(name: original_name, email: original_email)
    user = User.last

    assert !user.name_previously_changed?
    assert !user.email_previously_changed?

    user.update!(name: new_name, email: new_email)

    assert user.name_previously_changed?
    assert user.email_previously_changed?

    assert_equal [original_name, new_name], user.name_previous_change
    assert_equal [original_email, new_email], user.email_previous_change

    assert_equal original_name, user.name_previously_was
    assert_equal original_email, user.email_previously_was

    # ensure updated
    assert_equal original_name, user.name_before_last_save
    assert_equal original_email, user.email_before_last_save
  end

  def test_dirty_bad_ciphertext
    user = User.create!(email_ciphertext: "bad")

    assert_output(nil, /Decrypting previous value failed/) do
      user.email = "test@example.org"
    end

    if mongoid?
      assert user.email_changed?
    else
      assert_nil user.email_was
    end
  end

  def test_dirty_nil
    user = User.new
    assert_nil user.email
    user.email = "test@example.org"
    assert_nil user.email_was
    assert_nil user.changes["email"][0] unless mongoid?
    user.email = "new@example.org"
    assert_nil user.email_was
    assert_nil user.changes["email"][0] unless mongoid?
    user.email = nil
    assert_nil user.email_was
    assert_empty user.changes unless mongoid?
  end

  def test_dirty_type_cast
    skip if mongoid?

    user = User.create!(signed_at2: Time.now)
    user = User.last
    user.signed_at2 = Time.now
    assert_kind_of Time, user.signed_at2_was
  end

  def test_attributes
    skip if mongoid?

    User.create!(email: "test@example.org")
    user = User.last
    assert_equal "test@example.org", user.attributes["email"]
  end

  def test_attributes_not_loaded
    skip if mongoid?

    User.create!(email: "test@example.org")
    user = User.select("id", "phone_ciphertext").last
    assert_nil user.attributes["email"]
    assert !user.has_attribute?("name")
    assert !user.has_attribute?(:name)

    assert_equal ["id", "phone_ciphertext", "phone"], user.attributes.keys
    assert_equal ["id", "phone_ciphertext", "phone"], user.attribute_names
    assert user.has_attribute?("phone_ciphertext")
    assert user.has_attribute?(:phone_ciphertext)
    assert user.has_attribute?("phone")
    assert user.has_attribute?(:phone)
    assert !user.has_attribute?("email")
    assert !user.has_attribute?(:email)

    user = User.select("id AS email_ciphertext").last
    assert_raises(Lockbox::DecryptionError) do
      user.attributes
    end
  end

  def test_attributes_bad_ciphertext
    skip if mongoid?

    User.create!(email_ciphertext: "bad")
    user = User.last
    assert_raises(Lockbox::DecryptionError) do
      user.attributes
    end
  end

  def test_attributes_default
    skip if mongoid?

    _, stderr = capture_io do
      Admin.has_encrypted :code
    end
    assert_match "[lockbox] WARNING: attributes with `:default` option are not supported. Use `after_initialize` instead.", stderr
  end

  def test_keyed_getter
    skip if mongoid?

    user = User.create!(name: "Test", email: "test@example.org")
    assert_equal "Test", user[:name]
    assert_equal "Test", user["name"]
    assert_equal "test@example.org", user[:email]
    assert_equal "test@example.org", user["email"]

    user = User.last
    assert_equal "Test", user[:name]
    assert_equal "Test", user["name"]
    assert_equal "test@example.org", user[:email]
    assert_equal "test@example.org", user["email"]
  end

  def test_keyed_setter
    skip if mongoid?

    user = User.create!
    user[:name] = "Test"
    user[:email] = "test@example.org"
    user.save!

    user = User.last
    assert_equal "Test", user.name
    assert_equal "test@example.org", user.email
  end

  def test_inspect
    user = User.create!(email: "test@example.org")
    assert_includes user.inspect, "email: [FILTERED]"
    refute_includes user.inspect, "email_ciphertext"
    refute_includes user.inspect, "test@example.org"
  end

  # follow same behavior as filter_attributes
  def test_inspect_nil
    user = User.new

    if mongoid?
      refute_includes user.inspect, "email"
    else
      assert_includes user.inspect, "email: nil"
    end
    refute_includes user.inspect, "email_ciphertext"
    refute_includes user.inspect, "test@example.org"
  end

  def test_inspect_select
    return if mongoid?

    User.create!(email: "test@example.org")
    user = User.select(:id).last
    refute_includes user.inspect, "email"
    refute_includes user.inspect, "email_ciphertext"
    refute_includes user.inspect, "test@example.org"
  end

  def test_inspect_select_ciphertext
    return if mongoid?

    User.create!(email: "test@example.org")
    user = User.select(:id, :email_ciphertext).last
    assert_includes user.inspect, "email: [FILTERED]"
    refute_includes user.inspect, "email_ciphertext"
    refute_includes user.inspect, "test@example.org"
  end

  def test_inspect_filter_attributes
    skip if mongoid?

    previous_value = User.filter_attributes
    begin
      User.filter_attributes = ["name"]
      user = User.create!(name: "Test")
      assert_includes user.inspect, "name: [FILTERED]"
      refute_includes user.inspect, "Test"

      # Active Record still shows nil for filtered attributes
      user = User.create!(name: nil)
      assert_includes user.inspect, "name: nil"
    ensure
      User.filter_attributes = previous_value
    end
  end

  def test_serializable_hash
    user = User.create!(email: "test@example.org")
    assert_nil user.serializable_hash["email"]
    assert_nil user.serializable_hash["email_ciphertext"]
  end

  def test_to_json
    user = User.create!(email: "test@example.org")
    assert_nil user.as_json["email"]
    assert_nil user.as_json["email_ciphertext"]
    refute_includes user.to_json, "email"
    refute_includes user.to_json, "test@example.org"
    assert_equal "test@example.org", user.as_json(methods: [:email])["email"]
  end

  def test_filter_attributes
    skip if mongoid?

    assert_includes User.filter_attributes, /\Aemail\z/
    refute_includes User.filter_attributes, /\Aemail_ciphertext\z/
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

    # loaded
    # ensure attributes is set before we call email
    assert_equal original_email, user.attributes["email"] unless mongoid?
    assert_equal original_email, user.email
  end

  def test_update_column
    skip if mongoid?

    user = User.create!(name: "Test", email: "test@example.org")

    user.update_column(:name, "New")
    assert_equal "New", user.name
    user.update_column(:email, "new@example.org")
    assert_equal "new@example.org", user.email

    user = User.last
    assert_equal "New", user.name
    assert_equal "new@example.org", user.email
  end

  def test_update_columns
    skip if mongoid?

    user = User.create!(name: "Test", email: "test@example.org")

    user.update_columns(name: "New", email: "new@example.org")
    assert_equal "New", user.name
    assert_equal "new@example.org", user.email

    user = User.last
    assert_equal "New", user.name
    assert_equal "new@example.org", user.email
  end

  def test_update_attribute
    user = User.create!(name: "Test", email: "test@example.org")

    user.update_attribute(:name, "New")
    assert_equal "New", user.name
    user.update_attribute(:email, "new@example.org")
    assert_equal "new@example.org", user.email

    user = User.last
    assert_equal "New", user.name
    assert_equal "new@example.org", user.email
  end

  def test_write_attribute
    skip if mongoid?

    user = User.create!(email: "test@example.org")
    user.write_attribute(:email, "new@example.org")
    user.save!

    assert_equal "new@example.org", User.last.email
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

  def test_hybrid_no_decryption_key
    Agent.delete_all

    agent = Agent.create!(email: "test@example.org")
    original_email_ciphertext = agent.email_ciphertext
    assert_equal agent, Agent.last

    agent = Agent.last
    agent.name = "Test"
    agent.save!

    agent = Agent.last
    assert_equal original_email_ciphertext, agent.email_ciphertext

    agent = Agent.last
    agent.email = "new@example.org"
    agent.save!

    agent = Agent.last
    assert agent.inspect
    assert_nil agent.attributes["email"]
    assert agent.attributes["email_ciphertext"]

    # TODO change to Lockbox::DecryptionError?
    error = assert_raises(ArgumentError) do
      agent.email
    end
    assert_equal "No decryption key set", error.message
  end

  def test_hybrid_no_decryption_key_proc
    Agent.delete_all

    agent = Agent.create!(personal_email: "test@example.org")
    original_email_ciphertext = agent.personal_email_ciphertext
    assert_equal agent, Agent.last

    agent = Agent.last
    agent.name = "Test"
    agent.save!

    agent = Agent.last
    assert_equal original_email_ciphertext, agent.personal_email_ciphertext

    agent = Agent.last
    agent.personal_email = "new@example.org"
    agent.save!

    agent = Agent.last
    assert agent.inspect
    assert_nil agent.attributes["personal_email"]
    assert agent.attributes["personal_email_ciphertext"]

    # TODO change to Lockbox::DecryptionError?
    error = assert_raises(ArgumentError) do
      agent.personal_email
    end
    assert_equal "No decryption key set", error.message
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

  def test_associated_data
    user = User.create!(name: "Test", region: "Data")
    assert_equal "Data", User.last.region
    user.update!(name: "New")
    assert_raises(Lockbox::DecryptionError) do
      User.last.region
    end
  end

  def test_attribute_key_encrypted_column
    email = "test@example.org"
    user = User.create!(email: email)
    key = Lockbox.attribute_key(table: "users", attribute: "email_ciphertext")
    box = Lockbox.new(key: key, encode: true)
    assert_equal email, box.decrypt(user.email_ciphertext)
  end

  # TODO prefer encrypt_email
  def test_generate_attribute_ciphertext
    email = "test@example.org"
    ciphertext = User.generate_email_ciphertext(email)
    key = Lockbox.attribute_key(table: "users", attribute: "email_ciphertext")
    box = Lockbox.new(key: key, encode: true)
    assert_equal email, box.decrypt(ciphertext)
  end

  # TODO prefer decrypt_email
  def test_decrypt_attribute_ciphertext
    email = "test@example.org"
    user = User.create!(email: email)
    assert_equal email, User.decrypt_email_ciphertext(user.email_ciphertext)
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

  def test_bad_master_key
    Lockbox.stub(:master_key, "bad") do
      assert_raises(Lockbox::Error) do
        User.create!(email: "test@example.org")
      end
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

  def test_unencrypted_column
    if mongoid?
      assert_output(nil, /WARNING: Unencrypted field with same name: state/) do
        User.create!(state: "CA")
      end
      # not currently saved, but this is not guaranted
      assert_equal ["_id", "state_ciphertext"], User.collection.find.first.keys
    else
      assert_output(nil, /WARNING: Unencrypted column with same name: state/) do
        User.create!(state: "CA")
      end
      # currently saved
      result = User.connection.select_all("SELECT state FROM users").to_a
      assert_equal [{"state" => "CA"}], result
    end
  end

  def test_callable_options
    email = "test@example.org"
    admin = Admin.create!(other_email: email)
    box = Lockbox.new(key: "2"*64, encode: true)
    assert_equal email, box.decrypt(admin.other_email_ciphertext)
  end

  def test_callable_options_record
    email = "test@example.org"
    admin = Admin.create!(personal_email: email)
    box = Lockbox.new(key: admin.record_key, encode: true)
    assert_equal email, box.decrypt(admin.personal_email_ciphertext)
  end

  def test_symbol_options
    email = "test@example.org"
    admin = Admin.create!(email: email)
    box = Lockbox.new(key: admin.record_key, encode: true)
    assert_equal email, box.decrypt(admin.email_ciphertext)
  end

  def test_key_table_key_attribute
    email = "test@example.org"
    admin = Admin.create!(email_address: email)
    assert_equal email, User.decrypt_email_ciphertext(admin.email_address_ciphertext)
  end

  def test_previous_versions_key
    email = "test@example.org"
    key = User.lockbox_attributes[:email][:previous_versions][0].fetch(:key)
    box = Lockbox.new(key: key, encode: true)
    User.create!(email_ciphertext: box.encrypt(email))
    assert_equal email, User.last.email
  end

  def test_previous_versions_master_key
    email = "test@example.org"
    master_key = User.lockbox_attributes[:email][:previous_versions][1].fetch(:master_key)
    key = Lockbox.attribute_key(table: "users", attribute: "email_ciphertext", master_key: master_key)
    box = Lockbox.new(key: key, encode: true)
    User.create!(email_ciphertext: box.encrypt(email))
    assert_equal email, User.last.email
  end

  def test_previous_versions_key_table_key_attribute
    email = "test@example.org"
    key = Lockbox.attribute_key(table: "people", attribute: "email_ciphertext")
    box = Lockbox.new(key: key, encode: true)
    admin = Admin.create!(email_address_ciphertext: box.encrypt(email))
    assert_equal email, Admin.decrypt_email_address_ciphertext(admin.email_address_ciphertext)
  end

  def test_encrypted_attribute
    email = "test@example.org"
    admin = Admin.create!(work_email: email)
    assert admin.encrypted_email
  end

  def test_encrypted_attribute_duplicate
    error = assert_raises do
      Admin.has_encrypted :dup_email, encrypted_attribute: "encrypted_email"
    end
    assert_equal "Multiple encrypted attributes use the same column: encrypted_email", error.message
  end

  # uses key from encrypted attribute
  def test_encrypted_attribute_key
    email = "test@example.org"
    admin = Admin.create!(work_email: email)
    key = Lockbox.attribute_key(table: "admins", attribute: "encrypted_email")
    box = Lockbox.new(key: key, encode: true)
    assert_equal email, box.decrypt(admin.encrypted_email)
  end

  def test_encrypts_no_attributes
    error = assert_raises(ArgumentError) do
      Admin.has_encrypted
    end
    assert_equal "No attributes specified", error.message
  end

  def test_lockbox_encrypts_deprecated
    assert_output(nil, /DEPRECATION WARNING: `lockbox_encrypts` is deprecated in favor of `has_encrypted`/) do
      Admin.lockbox_encrypts :dep
    end
  end

  def test_encrypts_deprecated
    skip if !mongoid?
    assert_output(nil, /DEPRECATION WARNING: `encrypts` is deprecated in favor of `has_encrypted`/) do
      Admin.encrypts :dep2
    end
  end

  private

  def assert_no_plaintext_attributes
    Guard.all.each do |user|
      bad_keys = user.attributes.keys & %w(email phone ssn)
      assert_equal [], bad_keys, "Plaintext attribute exists"
    end
  end
end
