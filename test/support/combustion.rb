Combustion.path = "test/internal"

components = [:active_record, :active_job, :active_storage]

if Rails.version >= "6.0"
  components << :action_text
  Lockbox.encrypts_action_text_body
end

Combustion.initialize!(*components) do
  if ActiveRecord::VERSION::MAJOR < 6 && config.active_record.sqlite3.respond_to?(:represent_boolean_as_integer)
    config.active_record.sqlite3.represent_boolean_as_integer = true
  end

  if ActiveRecord::VERSION::STRING.to_f == 7.0
    config.active_record.legacy_connection_handling = false
  end

  config.logger = $logger

  config.time_zone = "Mountain Time (US & Canada)"

  config.active_job.queue_adapter = :inline

  config.active_storage.service = :test

  if ActiveRecord::VERSION::MAJOR >= 7
    config.active_storage.replace_on_assign_to_many = true
  end

  # TODO remove
  config.active_record.yaml_column_permitted_classes = [Symbol, Time]
end
