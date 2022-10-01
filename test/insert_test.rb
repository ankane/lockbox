require_relative "test_helper"

class InsertTest < Minitest::Test
  def setup
    skip if mongoid? || ActiveRecord::VERSION::MAJOR < 6

    User.delete_all
  end

  def test_insert
    User.insert({name: "Test", email: "test@example.org"})

    user = User.last
    assert_equal "Test", user.name
    assert_equal "test@example.org", user.email
  end

  def test_insert_all
    User.insert_all([{name: "Test", email: "test@example.org"}])

    user = User.last
    assert_equal "Test", user.name
    assert_equal "test@example.org", user.email
  end

  def test_insert_all!
    User.insert_all!([{name: "Test", email: "test@example.org"}])

    user = User.last
    assert_equal "Test", user.name
    assert_equal "test@example.org", user.email
  end

  def test_upsert
    User.upsert({name: "Test", email: "test@example.org"})

    user = User.last
    assert_equal "Test", user.name
    assert_equal "test@example.org", user.email
  end

  def test_upsert_all
    User.upsert_all([{name: "Test", email: "test@example.org"}])

    user = User.last
    assert_equal "Test", user.name
    assert_equal "test@example.org", user.email
  end
end
