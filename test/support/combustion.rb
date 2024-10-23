Combustion.path = "test/internal"

components = [:active_record, :active_job, :active_storage, :action_text]

Lockbox.encrypts_action_text_body

Combustion.initialize!(*components) do
  config.load_defaults Rails.version.to_f

  if ActiveRecord::VERSION::STRING.to_f == 7.0
    config.active_record.legacy_connection_handling = false
  end

  config.logger = $logger

  config.time_zone = "Mountain Time (US & Canada)"

  config.active_job.queue_adapter = :inline

  config.active_storage.service = :test

  if ActiveRecord::VERSION::STRING.to_f == 7.0
    config.active_storage.replace_on_assign_to_many = true
  end

  # TODO remove
  config.active_record.yaml_column_permitted_classes = [Symbol, Time]
end
