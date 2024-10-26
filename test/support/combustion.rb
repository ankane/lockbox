Combustion.path = "test/internal"

components = [:active_record, :active_job, :active_storage, :action_text]

Lockbox.encrypts_action_text_body

Combustion.initialize!(*components) do
  config.load_defaults Rails.version.to_f

  config.logger = $logger

  config.time_zone = "Mountain Time (US & Canada)"

  config.active_job.queue_adapter = :inline

  config.active_storage.service = :test

  # TODO remove
  config.active_record.yaml_column_permitted_classes = [Symbol, Time]
end
