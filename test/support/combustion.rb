Combustion.path = "test/internal"

components = [:active_record, :active_job]
components << :active_storage if Rails.version >= "5.2"

Combustion.initialize! *components do
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
