require "bundler/setup"
require "carrierwave"
require "combustion"
require "active_storage/engine" if Rails.version >= "5.2"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "active_record"
require "attr_encrypted"

CarrierWave.configure do |config|
  config.storage = :file
  config.store_dir = "/tmp/store"
  config.cache_dir = "/tmp/cache"
end

class TextUploader < CarrierWave::Uploader::Base
  encrypt key: Lockbox.generate_key

  process append: "!!"

  version :thumb do
    process append: ".."
  end

  def append(str)
    File.write(current_path, File.read(current_path) + str)
  end
end

class AvatarUploader < CarrierWave::Uploader::Base
  encrypt key: Lockbox.generate_key
end

class DocumentUploader < CarrierWave::Uploader::Base
  encrypt key: Lockbox.generate_key
end

class ImageUploader < CarrierWave::Uploader::Base
end

Combustion.path = "test/internal"
Combustion.initialize! :active_record, :active_job do
  if ActiveRecord::VERSION::MAJOR < 6 && config.active_record.sqlite3.respond_to?(:represent_boolean_as_integer)
    config.active_record.sqlite3.represent_boolean_as_integer = true
  end
  config.active_job.queue_adapter = :inline
  config.active_storage.service = :test if defined?(ActiveStorage)
end

if ENV["VERBOSE"]
  logger = ActiveSupport::Logger.new(STDOUT)
  ActiveRecord::Base.logger = logger
  ActiveJob::Base.logger = logger
  ActiveStorage.logger = logger if defined?(ActiveStorage)
end

require "carrierwave/orm/activerecord"
