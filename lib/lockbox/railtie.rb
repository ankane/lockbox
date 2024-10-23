module Lockbox
  class Railtie < Rails::Railtie
    initializer "lockbox" do |app|
      if defined?(Rails.application.credentials)
        # needs to work when lockbox key has a string value
        Lockbox.master_key ||= Rails.application.credentials.try(:lockbox).try(:fetch, :master_key, nil)
      end

      require "lockbox/carrier_wave_extensions" if defined?(CarrierWave)

      if defined?(ActiveStorage)
        require "lockbox/active_storage_extensions"

        ActiveStorage::Attached.prepend(Lockbox::ActiveStorageExtensions::Attached)
        ActiveStorage::Attached::Changes::CreateOne.prepend(Lockbox::ActiveStorageExtensions::CreateOne)
        ActiveStorage::Attached::One.prepend(Lockbox::ActiveStorageExtensions::AttachedOne)
        ActiveStorage::Attached::Many.prepend(Lockbox::ActiveStorageExtensions::AttachedMany)

        ActiveSupport.on_load(:active_storage_attachment) do
          prepend Lockbox::ActiveStorageExtensions::Attachment
        end
        ActiveSupport.on_load(:active_storage_blob) do
          prepend Lockbox::ActiveStorageExtensions::Blob
        end
      end
    end
  end
end
