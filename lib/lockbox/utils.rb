module Lockbox
  class Utils
    def self.build_box(context, options, table, attribute)
      options = options.except(:attribute, :encrypted_attribute, :migrating, :attached, :type)
      options[:encode] = false unless options.key?(:encode)
      options.each do |k, v|
        options[k] = value_in_context(context, k, v)
      end

      unless options[:key] || options[:encryption_key] || options[:decryption_key]
        options[:key] =
          Lockbox.attribute_key(
            table: options.delete(:key_table) || table,
            attribute: options.delete(:key_attribute) || attribute,
            master_key: options.delete(:master_key),
            encode: false
          )
      end

      if options[:previous_versions].is_a?(Array)
        options[:previous_versions] = options[:previous_versions].dup
        options[:previous_versions].each_with_index do |version, i|
          if !(version[:key] || version[:encryption_key] || version[:decryption_key]) && version[:master_key]
            # could also use key_table and key_attribute from options
            # when specified, but keep simple for now
            # also, this change isn't backward compatible
            key =
              Lockbox.attribute_key(
                table: version.delete(:key_table) || table,
                attribute: version.delete(:key_attribute) || attribute,
                master_key: version.delete(:master_key),
                encode: false
              )
            options[:previous_versions][i] = version.merge(key: key)
          end
          options[:previous_versions][i].each do |k, v|
            options[:previous_versions][i][k] = value_in_context(context, k, v)
          end
        end
      end

      Lockbox.new(**options)
    end

    def self.value_in_context(context, key, value)
      if value.respond_to?(:call)
        # context not present for pluck
        # still possible to use if not dependent on context
        context ? context.instance_exec(&value) : value.call
      elsif value.is_a?(Symbol)
        # context not present for pluck
        raise Error, "Not available since :#{key} depends on record" unless context
        context.send(value)
      else
        value
      end
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
