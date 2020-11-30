require_relative "test_helper"

class MigrateTest < Minitest::Test
  def setup
    Robot.delete_all
  end

  def test_migrate
    10.times do |i|
      Robot.create!(name: "User #{i}", email: "test#{i}@example.org")
    end
    Robot.update_all(name_ciphertext: nil, email_ciphertext: nil)
    Lockbox.migrate(Robot, batch_size: 5)
    robot = Robot.last
    assert_equal robot.name, robot.migrated_name
    assert_equal robot.email, robot.migrated_email
  end

  def test_migrate_relation
    robots = ["Hi", "Bye"].map { |v| Robot.create!(name: v) }
    Robot.update_all(name_ciphertext: nil)
    Lockbox.migrate(Robot.where(id: robots.first.id))
    robots.map(&:reload)
    assert_equal robots.first.name, robots.first.migrated_name
    assert_nil robots.last.migrated_name
  end

  def test_migrate_restart
    10.times do |i|
      Robot.create!(name: "User #{i}", email: "test#{i}@example.org")
    end
    Robot.update_all(name_ciphertext: nil, email_ciphertext: nil)
    Lockbox.migrate(Robot)
    Lockbox.migrate(Robot, restart: true)
    robot = Robot.last
    assert_equal robot.name, robot.migrated_name
    assert_equal robot.email, robot.migrated_email
  end

  def test_migrating_assignment
    Robot.create!(name: "Hi")
    Robot.update_all(name_ciphertext: nil)
    robot = Robot.last
    robot.name = "Bye"
    assert_equal "Bye", robot.migrated_name
    robot.save(validate: false)
    assert_equal "Bye", Robot.last.migrated_name
  end

  def test_migrating_update_column
    skip if mongoid?

    robot = Robot.create!(name: "Hi")
    robot.update_column(:name, "Bye")

    assert_equal "Bye", robot.name
    assert_equal "Bye", robot.migrated_name
  end

  def test_migrating_update_columns
    skip if mongoid?

    robot = Robot.create!(name: "Hi")
    robot.update_columns(name: "Bye")

    assert_equal "Bye", robot.name
    assert_equal "Bye", robot.migrated_name
  end

  def test_migrating_restore_reset
    robot = Robot.create!(name: "Hi")
    robot.name = "Bye"
    if mongoid?
      robot.reset_name!
    else
      robot.restore_name!
    end
    assert_equal "Hi", robot.migrated_name
  end

  def test_migrate_nothing
    Lockbox.migrate(Post)
  end

  def test_migrate_serialized
    skip if mongoid?

    10.times do |i|
      Robot.create!(properties: ["hi", "bye"])
    end
    Robot.update_all(properties_ciphertext: nil)
    Lockbox.migrate(Robot, batch_size: 5)
    robot = Robot.last
    # deserialization should work on migrated attributes
    assert_equal robot.properties, robot.migrated_properties
  end

  def test_filter_attributes
    skip if mongoid? || ActiveRecord::VERSION::MAJOR < 6

    assert_includes Robot.filter_attributes, "migrated_email"
    refute_includes Robot.filter_attributes, "email_ciphertext"

    # user likely wants original attribute in filter_attributes as well
    # but should already be there if it's sensitive
    # and the attribute isn't managed by Lockbox yet
    refute_includes Robot.filter_attributes, "email"
  end
end
