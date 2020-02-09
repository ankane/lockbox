Combustion.path = "test/internal"

Combustion.initialize! :active_record, :active_job do
  if ActiveRecord::VERSION::MAJOR < 6 && config.active_record.sqlite3.respond_to?(:represent_boolean_as_integer)
    config.active_record.sqlite3.represent_boolean_as_integer = true
  end
  config.active_job.queue_adapter = :inline
  config.active_storage.service = :test if defined?(ActiveStorage)
  config.time_zone = "Mountain Time (US & Canada)"
end

ActiveStorage.logger = $logger if defined?(ActiveStorage)
ActiveJob::Base.logger = $logger
