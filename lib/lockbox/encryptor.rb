module Lockbox
  class Encryptor
    def initialize(**options)
      options = Lockbox.default_options.merge(options)
      previous_versions = options.delete(:previous_versions)

      @boxes =
        [Box.new(options)] +
        Array(previous_versions).map { |v| Box.new({key: options[:key]}.merge(v)) }
    end

    def encrypt(message, **options)
      message = check_string(message, "message")
      @boxes.first.encrypt(message, **options)
    end

    def decrypt(ciphertext, **options)
      ciphertext = check_string(ciphertext, "ciphertext")

      # ensure binary
      if ciphertext.encoding != Encoding::BINARY
        # dup to prevent mutation
        ciphertext = ciphertext.dup.force_encoding(Encoding::BINARY)
      end

      @boxes.each_with_index do |box, i|
        begin
          return box.decrypt(ciphertext, **options)
        rescue => e
          # returning DecryptionError instead of PaddingError
          # is for end-user convenience, not for security
          error_classes = [DecryptionError, PaddingError]
          error_classes << RbNaCl::LengthError if defined?(RbNaCl::LengthError)
          error_classes << RbNaCl::CryptoError if defined?(RbNaCl::CryptoError)
          if error_classes.any? { |ec| e.is_a?(ec) }
            raise DecryptionError, "Decryption failed" if i == @boxes.size - 1
          else
            raise e
          end
        end
      end
    end

    def encrypt_io(io, **options)
      new_io = Lockbox::IO.new(encrypt(io.read, **options))
      copy_metadata(io, new_io)
      new_io
    end

    def decrypt_io(io, **options)
      new_io = Lockbox::IO.new(decrypt(io.read, **options))
      copy_metadata(io, new_io)
      new_io
    end

    def decrypt_str(ciphertext, **options)
      message = decrypt(ciphertext, **options)
      message.force_encoding(Encoding::UTF_8)
    end

    private

    def check_string(str, name)
      str = str.read if str.respond_to?(:read)
      raise TypeError, "can't convert #{name} to string" unless str.respond_to?(:to_str)
      str.to_str
    end

    def copy_metadata(source, target)
      target.original_filename =
        if source.respond_to?(:original_filename)
          source.original_filename
        elsif source.respond_to?(:path)
          File.basename(source.path)
        end
      target.content_type = source.content_type if source.respond_to?(:content_type)
      target.set_encoding(source.external_encoding) if source.respond_to?(:external_encoding)
    end

    # legacy for attr_encrypted
    def self.encrypt(options)
      box(options).encrypt(options[:value])
    end

    # legacy for attr_encrypted
    def self.decrypt(options)
      box(options).decrypt(options[:value])
    end

    # legacy for attr_encrypted
    def self.box(options)
      options = options.slice(:key, :encryption_key, :decryption_key, :algorithm, :previous_versions)
      options[:algorithm] = "aes-gcm" if options[:algorithm] == "aes-256-gcm"
      Lockbox.new(options)
    end
  end
end
