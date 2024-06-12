require_relative "test_helper"

class PluckTest < Minitest::Test
  def setup
    skip if mongoid?

    User.delete_all
    Admin.delete_all
    Robot.delete_all
  end

  def test_symbol
    User.create!(name: "Test 1", email: "test1@example.org")
    User.create!(name: "Test 2", email: "test2@example.org")

    # unencrypted
    assert_equal ["Test 1", "Test 2"], User.order(:id).pluck(:name)
    assert_equal ["Test 1", "Test 2"], User.order(:id).pluck(:id, :name).map(&:last)

    # encrypted
    assert_equal ["test1@example.org", "test2@example.org"], User.order(:id).pluck(:email)
    assert_equal ["test1@example.org", "test2@example.org"], User.order(:id).pluck(:id, :email).map(&:last)

    # multiple
    assert_equal [["Test 1", "test1@example.org"], ["Test 2", "test2@example.org"]], User.order(:id).pluck(:name, :email)

    # where
    assert_equal ["test2@example.org"], User.where(name: "Test 2").pluck(:email)
  end

  def test_string
    User.create!(name: "Test 1", email: "test1@example.org")
    User.create!(name: "Test 2", email: "test2@example.org")

    # unencrypted
    assert_equal ["Test 1", "Test 2"], User.order(:id).pluck("name")
    assert_equal ["Test 1", "Test 2"], User.order(:id).pluck("id", "name").map(&:last)

    # encrypted
    assert_equal ["test1@example.org", "test2@example.org"], User.order(:id).pluck("email")
    assert_equal ["test1@example.org", "test2@example.org"], User.order(:id).pluck("id", "email").map(&:last)

    # multiple
    assert_equal [["Test 1", "test1@example.org"], ["Test 2", "test2@example.org"]], User.order(:id).pluck("name", "email")

    # where
    assert_equal ["test2@example.org"], User.where(name: "Test 2").pluck("email")
  end

  def test_object
    User.create!
    assert_equal ["Test"], User.pluck(Arel::Nodes::Quoted.new("Test"))
  end

  def test_callable_options_record
    Admin.create!(other_email: "test@example.org")
    assert_equal ["test@example.org"], Admin.pluck(:other_email)
  end

  def test_callable_options_record
    Admin.create!(personal_email: "test@example.org")
    error = assert_raises(NameError) do
      Admin.pluck(:personal_email)
    end
    assert_match /undefined local variable or method ['`]record_key'/, error.message
  end

  def test_symbol_options
    Admin.create!(email: "test@example.org")
    error = assert_raises(Lockbox::Error) do
      Admin.pluck(:email)
    end
    assert_equal "Not available since :key depends on record", error.message
  end

  def test_migrating
    Robot.create!(name: "Test 1")
    Robot.create!(name: "Test 2")

    Robot.update_all(name_ciphertext: nil)
    assert_equal ["Test 1", "Test 2"], Robot.order(:id).pluck(:name)
  end
end
