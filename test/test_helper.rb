require "bundler/setup"
require "carrierwave"
require "combustion"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"

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
