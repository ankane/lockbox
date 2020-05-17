module Lockbox
  class Utils
    def self.build_box(context, options, table, attribute)
      options = options.except(:attribute, :encrypted_attribute, :migrating, :attached, :type)
      options[:encode] = false unless options.key?(:encode)
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

      if options[:previous_versions].is_a?(Array)
        options[:previous_versions] = options[:previous_versions].dup
        options[:previous_versions].each_with_index do |version, i|
          if !(version[:key] || version[:encryption_key] || version[:decryption_key]) && version[:master_key]
            options[:previous_versions][i] = version.merge(key: Lockbox.attribute_key(table: table, attribute: attribute, master_key: version.delete(:master_key)))
          end
        end
      end

      Lockbox.new(**options)
    end

    def self.encrypted_options(record, name)
      record.class.respond_to?(:lockbox_attachments) ? record.class.lockbox_attachments[name.to_sym] : nil
    end

    def self.decode_key(key, size: 32, name: "Key")
      if key.encoding != Encoding::BINARY && key =~ /\A[0-9a-f]{#{size * 2}}\z/i
        key = [key].pack("H*")
      end

      raise Lockbox::Error, "#{name} must be 32 bytes (64 hex digits)" if key.bytesize != size
      raise Lockbox::Error, "#{name} must use binary encoding" if key.encoding != Encoding::BINARY

      key
    end

    def self.encrypted?(record, name)
      !encrypted_options(record, name).nil?
    end

    def self.encrypt_attachable(record, name, attachable)
      io = nil

      ActiveSupport::Notifications.instrument("encrypt_file.lockbox", {name: name}) do
        options = encrypted_options(record, name)
        box = build_box(record, options, record.class.table_name, name)

        case attachable
        when ActionDispatch::Http::UploadedFile, Rack::Test::UploadedFile
          io = attachable
          attachable = {
            io: box.encrypt_io(io),
            filename: attachable.original_filename,
            content_type: attachable.content_type
          }
        when Hash
          io = attachable[:io]
          attachable = attachable.dup
          attachable[:io] = box.encrypt_io(io)
        else
          # TODO raise ArgumentError
          raise NotImplementedError, "Could not find or build blob: expected attachable, got #{attachable.inspect}"
        end

        # don't analyze encrypted data
        metadata = {"analyzed" => true}
        metadata["encrypted"] = true if options[:migrating]
        attachable[:metadata] = (attachable[:metadata] || {}).merge(metadata)
      end

      # set content type based on unencrypted data
      # keep synced with ActiveStorage::Blob#extract_content_type
      attachable[:io].extracted_content_type = Marcel::MimeType.for(io, name: attachable[:filename].to_s, declared_type: attachable[:content_type])

      attachable
    end

    def self.decrypt_result(record, name, options, result)
      ActiveSupport::Notifications.instrument("decrypt_file.lockbox", {name: name}) do
        Utils.build_box(record, options, record.class.table_name, name).decrypt(result)
      end
    end

    def self.rebuild_attachable(attachment)
      {
        io: StringIO.new(attachment.download),
        filename: attachment.filename,
        content_type: attachment.content_type
      }
    end
  end
end
