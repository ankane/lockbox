class Lockbox
  class Railtie < Rails::Railtie
    initializer "lockbox" do |app|
      require "lockbox/carrier_wave_extensions" if defined?(CarrierWave)

      if defined?(ActiveStorage)
        require "lockbox/active_storage_extensions"
        ActiveStorage::Attached.prepend(Lockbox::ActiveStorageExtensions::Attached)
        ActiveStorage::Attached::One.prepend(Lockbox::ActiveStorageExtensions::AttachedOne)
        ActiveStorage::Attached::Many.prepend(Lockbox::ActiveStorageExtensions::AttachedMany)
        ActiveRecord::Base.extend(Lockbox::ActiveStorageExtensions::Model) if defined?(ActiveRecord)
      end

      app.config.to_prepare do
        if defined?(ActiveStorage)
          ActiveStorage::Attachment.include(Lockbox::ActiveStorageExtensions::Attachment)
        end
      end
    end
  end
end
