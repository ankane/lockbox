Combustion.path = "test/internal"

components = [:active_record, :active_job]
components << :active_storage if Rails.version >= "5.2"

if Rails.version >= "6.0"
  components << :action_text
  Lockbox.encrypts_action_text_body
end

Combustion.initialize!(*components) do
  if ActiveRecord::VERSION::MAJOR < 6 && config.active_record.sqlite3.respond_to?(:represent_boolean_as_integer)
    config.active_record.sqlite3.represent_boolean_as_integer = true
  end

  if ActiveRecord::VERSION::MAJOR >= 7
    config.active_record.legacy_connection_handling = false
  end

  config.logger = $logger

  config.time_zone = "Mountain Time (US & Canada)"

  config.active_job.queue_adapter = :inline

  if defined?(ActiveStorage)
    config.active_storage.service = :test

    if ActiveRecord::VERSION::MAJOR >= 7
      config.active_storage.replace_on_assign_to_many = true
    end
  end
end
