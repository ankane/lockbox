class Lockbox
  module Model
    def attached_encrypted(attribute, **options)
      warn "[lockbox] DEPRECATION WARNING: Use encrypts_attached instead"
      encrypts_attached(attribute, **options)
    end

    def encrypts_attached(*attributes, **options)
      attributes.each do |name|
        name = name.to_sym

        class_eval do
          @lockbox_attachments ||= {}

          unless respond_to?(:lockbox_attachments)
            def self.lockbox_attachments
              parent_attachments =
                if superclass.respond_to?(:lockbox_attachments)
                  superclass.lockbox_attachments
                else
                  {}
                end

              parent_attachments.merge(@lockbox_attachments || {})
            end
          end

          raise "Duplicate encrypted attachment: #{name}" if lockbox_attachments[name]
          @lockbox_attachments[name] = options
        end
      end
    end

    def encrypts(*attributes, **options)
      attributes.each do |name|
        # add default options
        encrypted_attribute = "#{name}_ciphertext"

        options = options.dup

        # migrating
        original_name = name.to_sym
        name = "migrated_#{name}" if options[:migrating]

        name = name.to_sym

        options[:attribute] = name.to_s
        options[:encrypted_attribute] = encrypted_attribute
        class_method_name = "generate_#{encrypted_attribute}"

        class_eval do
          if options[:migrating]
            before_validation do
              send("#{name}=", send(original_name)) if send("#{original_name}_changed?")
            end
          end

          @lockbox_attributes ||= {}

          unless respond_to?(:lockbox_attributes)
            def self.lockbox_attributes
              parent_attributes =
                if superclass.respond_to?(:lockbox_attributes)
                  superclass.lockbox_attributes
                else
                  {}
                end

              parent_attributes.merge(@lockbox_attributes || {})
            end
          end

          raise "Duplicate encrypted attribute: #{original_name}" if lockbox_attributes[original_name]
          @lockbox_attributes[original_name] = options

          if @lockbox_attributes.size == 1
            def serializable_hash(options = nil)
              options = options.try(:dup) || {}
              options[:except] = Array(options[:except])
              options[:except] += self.class.lockbox_attributes.values.reject { |v| v[:attached] }.flat_map { |v| [v[:attribute], v[:encrypted_attribute]] }
              super(options)
            end

            # use same approach as devise
            def inspect
              inspection =
                serializable_hash.map do |k,v|
                  "#{k}: #{respond_to?(:attribute_for_inspect) ? attribute_for_inspect(k) : v.inspect}"
                end
              "#<#{self.class} #{inspection.join(", ")}>"
            end
          end

          attribute name, :string

          define_method("#{name}=") do |message|
            # decrypt first for dirty tracking
            # don't raise error if can't decrypt previous
            begin
              send(name)
            rescue Lockbox::DecryptionError
              nil
            end

            ciphertext =
              if message.nil? || (message == "" && !options[:padding])
                message
              else
                self.class.send(class_method_name, message, context: self)
              end
            send("#{encrypted_attribute}=", ciphertext)

            super(message)
          end

          define_method(name) do
            message = super()
            unless message
              ciphertext = send(encrypted_attribute)
              message =
                if ciphertext.nil? || (ciphertext == "" && !options[:padding])
                  ciphertext
                else
                  ciphertext = Base64.decode64(ciphertext)
                  Lockbox::Utils.build_box(self, options, self.class.table_name, encrypted_attribute).decrypt(ciphertext)
                end

              # set previous attribute on first decrypt
              @attributes[name.to_s].instance_variable_set("@value_before_type_cast", message)

              # cache
              if respond_to?(:_write_attribute, true)
                _write_attribute(name, message)
              else
                raw_write_attribute(name, message)
              end
            end
            message
          end

          # for fixtures
          define_singleton_method class_method_name do |message, **opts|
            ciphertext = Lockbox::Utils.build_box(opts[:context], options, table_name, encrypted_attribute).encrypt(message)
            Base64.strict_encode64(ciphertext)
          end
        end
      end
    end
  end
end
