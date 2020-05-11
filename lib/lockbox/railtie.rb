module Lockbox
  class Railtie < Rails::Railtie
    initializer "lockbox" do |app|
      require "lockbox/carrier_wave_extensions" if defined?(CarrierWave)

      if defined?(ActiveStorage)
        require "lockbox/active_storage_extensions"

        ActiveStorage::Attached.prepend(Lockbox::ActiveStorageExtensions::Attached)
        if ActiveStorage::VERSION::MAJOR >= 6
          ActiveStorage::Attached::Changes::CreateOne.prepend(Lockbox::ActiveStorageExtensions::CreateOne)
        end
        ActiveStorage::Attached::One.prepend(Lockbox::ActiveStorageExtensions::AttachedOne)
        ActiveStorage::Attached::Many.prepend(Lockbox::ActiveStorageExtensions::AttachedMany)

        # use load hooks when possible
        if ActiveStorage::VERSION::MAJOR >= 6
          ActiveSupport.on_load(:active_storage_attachment) do
            include Lockbox::ActiveStorageExtensions::Attachment
          end
          ActiveSupport.on_load(:active_storage_blob) do
            prepend Lockbox::ActiveStorageExtensions::Blob
          end
        else
          app.config.to_prepare do
            ActiveStorage::Attachment.include(Lockbox::ActiveStorageExtensions::Attachment)
            ActiveStorage::Blob.prepend(Lockbox::ActiveStorageExtensions::Blob)
          end
        end
      end
    end
  end
end
