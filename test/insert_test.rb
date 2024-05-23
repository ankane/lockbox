require_relative "test_helper"

class InsertTest < Minitest::Test
  def setup
    skip if mongoid? || ActiveRecord::VERSION::MAJOR < 6

    User.delete_all
  end

  def test_insert
    User.insert({name: "Test", email: "test@example.org"})
    User.insert({"name" => "New", "email" => "new@example.org"})

    users = User.order(:id).pluck(:name, :email)
    expected = [["Test", "test@example.org"], ["New", "new@example.org"]]
    assert_equal expected, users
  end

  def test_insert!
    User.insert!({name: "Test", email: "test@example.org"})
    User.insert!({"name" => "New", "email" => "new@example.org"})

    users = User.order(:id).pluck(:name, :email)
    expected = [["Test", "test@example.org"], ["New", "new@example.org"]]
    assert_equal expected, users
  end

  def test_insert_all
    User.insert_all([{name: "Test", email: "test@example.org"}])
    User.insert_all([{"name" => "New", "email" => "new@example.org"}])

    users = User.order(:id).pluck(:name, :email)
    expected = [["Test", "test@example.org"], ["New", "new@example.org"]]
    assert_equal expected, users
  end

  def test_insert_all!
    User.insert_all!([{name: "Test", email: "test@example.org"}])
    User.insert_all!([{"name" => "New", "email" => "new@example.org"}])

    users = User.order(:id).pluck(:name, :email)
    expected = [["Test", "test@example.org"], ["New", "new@example.org"]]
    assert_equal expected, users
  end

  def test_upsert
    User.upsert({id: 1, name: "Test", email: "test@example.org"})
    User.upsert({"id" => 1, "name" => "New", "email" => "new@example.org"})

    users = User.order(:id).pluck(:name, :email)
    expected = [["New", "new@example.org"]]
    assert_equal expected, users
  end

  def test_upsert_all
    User.upsert_all([{id: 1, name: "Test", email: "test@example.org"}])
    User.upsert_all([{"id" => 1, "name" => "New", "email" => "new@example.org"}])

    users = User.order(:id).pluck(:name, :email)
    expected = [["New", "new@example.org"]]
    assert_equal expected, users
  end

  def test_symbol_options
    error = assert_raises(Lockbox::Error) do
      Admin.upsert({email: "test@example.org"})
    end
    assert_equal "Not available since :key depends on record", error.message
  end
end
