require_relative "test_helper"

class RotateTest < Minitest::Test
  def setup
    User.delete_all
  end

  def test_rotate
    10.times do |i|
      User.create!(name: "name#{i}", city: "City #{i}", email: "test#{i}@example.org", balance: i.to_s)
    end

    user = User.last
    original_city_ciphertext = user.city_ciphertext
    original_email_ciphertext = user.email_ciphertext

    Lockbox.rotate(User, attributes: [:email], batch_size: 5)

    user = User.last
    assert_equal "City 9", user.city
    assert_equal "test9@example.org", user.email
    assert_equal original_city_ciphertext, user.city_ciphertext
    refute_equal original_email_ciphertext, user.email_ciphertext

    original_email_ciphertext = user.email_ciphertext
    original_balance_ciphertext = user.balance_ciphertext

    Lockbox.rotate(User, attributes: [:balance], batch_size: 5)

    user = User.last
    assert_equal "name9", user.name
    assert_equal "test9@example.org", user.email
    assert_equal original_email_ciphertext, user.email_ciphertext
    refute_equal original_balance_ciphertext, user.balance_ciphertext
  end

  def test_rotate_relation
    users = 2.times.map { |i| User.create!(email: "test#{i}@example.org") }
    original_ciphertexts = users.map(&:email_ciphertext)

    Lockbox.rotate(User.where(id: users.last.id), attributes: [:email])

    new_ciphertexts = users.map(&:reload).map(&:email_ciphertext)
    assert_equal original_ciphertexts.first, new_ciphertexts.first
    refute_equal original_ciphertexts.last, new_ciphertexts.last
  end

  def test_rotate_bad_attribute
    error = assert_raises(ArgumentError) do
      Lockbox.rotate(User, attributes: [:bad])
    end
    assert_equal "Bad attribute: bad", error.message
  end

  def test_rotation
    email = "test@example.org"
    key = User.lockbox_attributes[:email][:previous_versions].first[:key]
    box = Lockbox.new(key: key, encode: true)
    user = User.create!(email_ciphertext: box.encrypt(email))
    user = User.last
    assert_equal email, user.email
  end

  def test_rotation_master_key
    email = "test@example.org"
    master_key = User.lockbox_attributes[:email][:previous_versions].last[:master_key]
    key = Lockbox.attribute_key(table: "users", attribute: "email_ciphertext", master_key: master_key)
    box = Lockbox.new(key: key, encode: true)
    user = User.create!(email_ciphertext: box.encrypt(email))
    user = User.last
    assert_equal email, user.email
  end

  def test_rotation_with_associated_fields
    # Test Previous Versions associated_field email_ciphertext with key attr
    balance = "20"
    email = "test@example.org"
    key = User.lockbox_attributes[:balance][:previous_versions].first[:key]
    email_key = User.lockbox_attributes[:email][:previous_versions].first[:key]
    box = Lockbox.new(key: key, encode: true)
    email_box = Lockbox.new(key: email_key, encode: true)

    email_ciphertext = email_box.encrypt(email)
    user = User.create!(
      name: "testuser",
      email_ciphertext: email_ciphertext,
      balance_ciphertext: box.encrypt(balance, associated_data: email_ciphertext)
    )

    user = User.last

    assert_equal email, user.email
    assert_equal balance, user.balance
  end

  def test_rotation_with_associated_fields_mastery_key 
    # Test Previous Versions associated_field id with master key attr
    balance = "20"
    email = "test@example.org"
    name = "testuser"
    master_key = User.lockbox_attributes[:balance][:previous_versions][1].fetch(:master_key)
    key = Lockbox.attribute_key(table: "users", attribute: "balance_ciphertext", master_key: master_key)
    box = Lockbox.new(key: key, encode: true)
    user = User.create!(name: name, email: email)
    user.update!(
      balance_ciphertext: box.encrypt(balance, associated_data: user.id.to_s)
    )

    user = User.last
    assert_equal balance, user.balance
  end
end
