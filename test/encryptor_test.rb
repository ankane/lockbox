require_relative "test_helper"

class EncryptorTest < Minitest::Test
  def test_symmetric
    email = "test@example.org"
    User.create!(email: email)
    user = User.last
    assert_equal user.email, email
  end

  def test_rotation
    email = "test@example.org"
    key = User.encrypted_attributes[:email][:previous_versions].first[:key]
    box = Lockbox.new(key: key)
    user = User.create!(encrypted_email: Base64.encode64(box.encrypt(email)))
    user = User.last
    assert_equal user.email, email
  end

  def test_hybrid
    phone = "555-555-5555"
    User.create!(phone: phone)
    user = User.last
    assert_equal user.phone, phone
  end
end
