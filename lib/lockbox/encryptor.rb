module Lockbox
  module Encryptor
    extend self

    def encrypt(message, options)
      message = check_string(message)
      box_options = options.except(:encode, :previous_versions)
      box_options = Lockbox.default_options.merge(box_options) unless Lockbox.default_options.empty?

      ciphertext = Box.encrypt(message, box_options)
      ciphertext = [ciphertext].pack("m0") if options[:encode]
      ciphertext
    end

    def decrypt(ciphertext, options)
      ciphertext = ciphertext.unpack1("m") if options[:encode]
      ciphertext = check_string(ciphertext)

      if ciphertext.encoding != Encoding::BINARY
        ciphertext = ciphertext.dup.force_encoding(Encoding::BINARY)
      end

      box_options = options.except(:encode, :previous_versions)
      box_options = Lockbox.default_options.merge(box_options) unless Lockbox.default_options.empty?

      error_classes = [DecryptionError, PaddingError]
      error_classes << RbNaCl::LengthError if defined?(RbNaCl::LengthError)
      error_classes << RbNaCl::CryptoError if defined?(RbNaCl::CryptoError)

      begin
        return Box.decrypt(ciphertext, box_options)
      rescue *error_classes
        raise DecryptionError, "Decryption failed" unless options[:previous_versions]
      end

      previous_version = Array(options[:previous_versions])

      previous_version.each_with_index do |opts, i|
        next if opts.key?(:master_key)

        opts = opts.merge(key: box_options[:key]) unless opts.key?(:key)

        begin
          return Box.decrypt(ciphertext, opts)
        rescue *error_classes
          next unless i == previous_version.size - 1

          raise DecryptionError, "Decryption failed"
        end
      end

      raise DecryptionError, "Decryption failed"
    end

    def encrypt_io(io, options)
      new_io = Lockbox::IO.new(encrypt(io.read, options))
      copy_metadata(io, new_io)
      new_io
    end

    def decrypt_io(io, options)
      new_io = Lockbox::IO.new(decrypt(io.read, options))
      copy_metadata(io, new_io)
      new_io
    end

    def decrypt_str(ciphertext, options)
      message = decrypt(ciphertext, options)
      message.force_encoding(Encoding::UTF_8)
    end

    private

    def check_string(str)
      str = str.read if str.respond_to?(:read)
      # Ruby uses "no implicit conversion of Object into String"
      raise TypeError, "can't convert #{str.class.name} to String" unless str.respond_to?(:to_str)
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
  end
end
