require "bundler/setup"
require "carrierwave"
require "combustion"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"

$logger = ActiveSupport::Logger.new(ENV["VERBOSE"] ? STDOUT : nil)

require_relative "support/carrierwave"

def mongoid?
  defined?(Mongoid)
end

if mongoid?
  require_relative "support/mongoid"
else
  require_relative "support/combustion"
  require "carrierwave/orm/activerecord"
  require_relative "support/active_record"
end

Lockbox.master_key = SecureRandom.random_bytes(32)
