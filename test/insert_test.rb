require_relative "test_helper"

class InsertTest < Minitest::Test
  def setup
    skip if mongoid? || ActiveRecord::VERSION::MAJOR < 6

    User.delete_all
  end

  def test_insert
    _, err = capture_io do
      User.insert({name: "Test", email: "test@example.org", password: "testpassword"})
      User.insert({"name" => "New", "email" => "new@example.org", "password" => "newpassword"})
    end
    assert_match "[lockbox] Unable to associate id for password", err

    users = User.order(:id).pluck(:name, :email, :password)
    expected = [["Test", "test@example.org", nil], ["New", "new@example.org", nil]]
    assert_equal expected, users
  end

  def test_insert_all
    _, err = capture_io do
      User.insert_all([{name: "Test", email: "test@example.org", password: "testpassword"}])
      User.insert_all([{"name" => "New", "email" => "new@example.org", "password" => "newpassword"}])
    end
    assert_match "[lockbox] Unable to associate id for password", err

    users = User.order(:id).pluck(:name, :email, :password)
    expected = [["Test", "test@example.org", nil], ["New", "new@example.org", nil]]
    assert_equal expected, users
  end

  def test_insert_all!
    _, err = capture_io do
      User.insert_all!([{name: "Test", email: "test@example.org", password: "testpassword"}])
      User.insert_all!([{"name" => "New", "email" => "new@example.org", "password" => "newpassword"}])
    end
    assert_match "[lockbox] Unable to associate id for password", err

    users = User.order(:id).pluck(:name, :email, :password)
    expected = [["Test", "test@example.org", nil], ["New", "new@example.org", nil]]
    assert_equal expected, users
  end


  def test_insert_all_with_ids!
    _, err = capture_io do
      User.insert_all!([{id: 1, name: "Test", email: "test@example.org", password: "testpassword"}])
      User.insert_all!([{id: 2, "name" => "New", "email" => "new@example.org", "password" => "newpassword"}])
    end

    users = User.order(:id).pluck(:name, :email, :password)
    expected = [["Test", "test@example.org", "testpassword"], ["New", "new@example.org", "newpassword"]]
    assert_equal expected, users
  end

  def test_upsert
    User.upsert({id: 1, name: "Test", email: "test@example.org", password: "testpassword"})
    User.upsert({"id" => 1, "name" => "New", "email" => "new@example.org", "password" => "newpassword"})

    users = User.order(:id).pluck(:name, :email, :password)
    expected = [["New", "new@example.org", "newpassword"]]
    assert_equal expected, users
  end

  def test_upsert_all
    User.upsert_all([{id: 1, name: "Test", email: "test@example.org", password: "testpassword"}])
    User.upsert_all([{"id" => 1, "name" => "New", "email" => "new@example.org", "password" => "newpassword"}])

    users = User.order(:id).pluck(:name, :email, :password)
    expected = [["New", "new@example.org", "newpassword"]]
    assert_equal expected, users
  end

  def test_symbol_options
    error = assert_raises(Lockbox::Error) do
      Admin.upsert({email: "test@example.org"})
    end
    assert_equal "Not available since :key depends on record", error.message
  end
end
