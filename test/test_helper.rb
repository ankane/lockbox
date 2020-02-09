require "bundler/setup"
require "carrierwave"
require "combustion"
require "active_storage/engine" if Rails.version >= "5.2"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "rbnacl"

$logger = ActiveSupport::Logger.new(ENV["VERBOSE"] ? STDOUT : nil)

if defined?(Mongoid)
  require_relative "support/mongoid"
else
  require_relative "support/active_record"
end

require_relative "support/carrierwave"
require_relative "support/combustion"

ActiveStorage.logger = $logger if defined?(ActiveStorage)
ActiveJob::Base.logger = $logger

Lockbox.master_key = SecureRandom.random_bytes(32)
