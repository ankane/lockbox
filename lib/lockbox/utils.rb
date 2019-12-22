module Lockbox
  class Utils
    def self.build_box(context, options, table, attribute)
      options = options.except(:attribute, :encrypted_attribute, :migrating, :attached, :type, :encode)
      options.each do |k, v|
        if v.is_a?(Proc)
          options[k] = context.instance_exec(&v) if v.respond_to?(:call)
        elsif v.is_a?(Symbol)
          options[k] = context.send(v)
        end
      end

      unless options[:key] || options[:encryption_key] || options[:decryption_key]
        options[:key] = Lockbox.attribute_key(table: table, attribute: attribute, master_key: options.delete(:master_key))
      end

      Lockbox.new(options)
    end

    def self.encrypted_options(record, name)
      record.class.respond_to?(:lockbox_attachments) ? record.class.lockbox_attachments[name.to_sym] : nil
    end

    def self.decode_key(key, size: 32)
      if key.encoding != Encoding::BINARY && key =~ /\A[0-9a-f]{#{size * 2}}\z/i
        key = [key].pack("H*")
      end

      raise Lockbox::Error, "Key must use binary encoding" if key.encoding != Encoding::BINARY
      raise Lockbox::Error, "Key must be 32 bytes" if key.bytesize != size

      key
    end

    def self.encrypted?(record, name)
      !encrypted_options(record, name).nil?
    end

    def self.encrypt_attachable(record, name, attachable)
      options = encrypted_options(record, name)
      box = build_box(record, options, record.class.table_name, name)

      case attachable
      when ActionDispatch::Http::UploadedFile, Rack::Test::UploadedFile
        attachable = {
          io: box.encrypt_io(attachable),
          filename: attachable.original_filename,
          content_type: attachable.content_type
        }
      when Hash
        attachable = {
          io: box.encrypt_io(attachable[:io]),
          filename: attachable[:filename],
          content_type: attachable[:content_type]
        }
      else
        raise NotImplementedError, "Not supported"
      end

      attachable
    end
  end
end
