# legacy for attr_encrypted
class Lockbox
  class Encryptor
    def self.encrypt(options)
      box(options).encrypt(options[:value])
    end

    def self.decrypt(options)
      box(options).decrypt(options[:value])
    end

    def self.box(options)
      options = options.slice(:key, :encryption_key, :decryption_key, :algorithm, :previous_versions)
      options[:algorithm] = "aes-gcm" if options[:algorithm] == "aes-256-gcm"
      Lockbox.new(options)
    end
  end
end
