require_relative "test_helper"

class RotateTest < Minitest::Test
  def setup
    User.delete_all
  end

  def test_rotate
    10.times do |i|
      User.create!(city: "City #{i}", email: "test#{i}@example.org")
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
end
