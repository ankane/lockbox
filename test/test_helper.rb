require "bundler/setup"
require "carrierwave"
require "combustion"
Bundler.require(:default)
require "minitest/autorun"

$logger = ActiveSupport::Logger.new(ENV["VERBOSE"] ? STDOUT : nil)

def mongoid?
  defined?(Mongoid)
end

require_relative "support/carrierwave"
require_relative "support/shrine"

if mongoid?
  require_relative "support/mongoid"
else
  require_relative "support/combustion"
  require "carrierwave/orm/activerecord"
  require_relative "support/active_record"
end

Lockbox.master_key = SecureRandom.random_bytes(32)

class Minitest::Test
  def with_master_key(key)
    previous_value = Lockbox.master_key
    begin
      Lockbox.master_key = key
      yield
    ensure
      Lockbox.master_key = previous_value
    end
  end

  def jruby?
    RUBY_ENGINE == "jruby"
  end

  def truffleruby?
    RUBY_ENGINE == "truffleruby"
  end
end
