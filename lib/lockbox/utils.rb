class Lockbox
  class Utils
    def self.build_box(context, options)
      options = options.dup
      options.each do |k, v|
        if v.is_a?(Proc)
          options[k] = context.instance_exec(&v) if v.respond_to?(:call)
        elsif v.is_a?(Symbol)
          options[k] = context.send(v)
        end
      end

      Lockbox.new(options)
    end

    def self.encrypted_options(record, name)
      record.class.respond_to?(:encrypted_attachments) && record.class.encrypted_attachments[name.to_sym]
    end
  end
end
