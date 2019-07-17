class Lockbox
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
      record.class.respond_to?(:lockbox_attachments) && record.class.lockbox_attachments[name.to_sym]
    end

    def self.decode_key(key)
      if key.encoding != Encoding::BINARY && key =~ /\A[0-9a-f]{64,128}\z/i
        key = [key].pack("H*")
      end
      key
    end
  end
end
