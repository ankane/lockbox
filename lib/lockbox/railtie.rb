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

        # notifications only used for Active Storage right now
        require "lockbox/log_subscriber"
        Lockbox::LogSubscriber.attach_to :lockbox
      end

      app.config.to_prepare do
        if defined?(ActiveStorage)
          ActiveStorage::Attachment.include(Lockbox::ActiveStorageExtensions::Attachment)
          ActiveStorage::Blob.prepend(Lockbox::ActiveStorageExtensions::Blob)
        end
      end
    end
  end
end
