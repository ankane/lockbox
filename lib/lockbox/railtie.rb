class Lockbox
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
      end

      app.config.to_prepare do
        if defined?(ActiveStorage)
          ActiveStorage::Attachment.include(Lockbox::ActiveStorageExtensions::Attachment)
        end
      end
    end
  end
end
