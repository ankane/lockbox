CarrierWave.configure do |config|
  config.storage = :file
  config.store_dir = "/tmp/store"
  config.cache_dir = "/tmp/cache"
end

class TextUploader < CarrierWave::Uploader::Base
  encrypt

  process append: "!!"

  version :thumb do
    process append: ".."
  end

  def append(str)
    File.write(current_path, File.read(current_path) + str)
  end
end

class AvatarUploader < CarrierWave::Uploader::Base
  encrypt
end

class DocumentUploader < CarrierWave::Uploader::Base
  encrypt
end

class ImageUploader < CarrierWave::Uploader::Base
end
