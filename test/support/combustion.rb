require "active_storage/engine" if Rails.version >= "5.2"

if Rails.version >= "6.0"
  require "action_text/engine"
  Lockbox.encrypts_rich_text_body
end

Combustion.path = "test/internal"

Combustion.initialize! :active_record, :active_job do
  if ActiveRecord::VERSION::MAJOR < 6 && config.active_record.sqlite3.respond_to?(:represent_boolean_as_integer)
    config.active_record.sqlite3.represent_boolean_as_integer = true
  end

  config.time_zone = "Mountain Time (US & Canada)"

  config.active_job.queue_adapter = :inline
  config.active_job.logger = $logger

  if defined?(ActiveStorage)
    config.active_storage.logger = $logger
    config.active_storage.service = :test
  end
end
