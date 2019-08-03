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

    def encrypts(*attributes, encode: true, **options)
      # support objects
      # case options[:type]
      # when Date
      #   options[:type] = :date
      # when Time
      #   options[:type] = :datetime
      # when JSON
      #   options[:type] = :json
      # when Hash
      #   options[:type] = :hash
      # when String
      #   options[:type] = :string
      # when Integer
      #   options[:type] = :integer
      # when Float
      #   options[:type] = :float
      # end

      raise ArgumentError, "Unknown type: #{options[:type]}" unless [nil, :string, :boolean, :date, :datetime, :time, :integer, :float, :binary, :json, :hash].include?(options[:type])

      attribute_type =
        case options[:type]
        when nil, :json, :hash
          :string
        when :integer
          ActiveModel::Type::Integer.new(limit: 8)
        else
          options[:type]
        end

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
          @lockbox_attributes[original_name] = options.merge(encode: encode)

          if @lockbox_attributes.size == 1
            def serializable_hash(options = nil)
              options = options.try(:dup) || {}
              options[:except] = Array(options[:except])
              options[:except] += self.class.lockbox_attributes.values.flat_map { |v| [v[:attribute], v[:encrypted_attribute]] }
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

            # needed for in-place modifications
            # assigned attributes are encrypted on assignment
            # and then again here
            before_save do
              self.class.lockbox_attributes.each do |_, lockbox_attribute|
                attribute = lockbox_attribute[:attribute]

                if changes.include?(attribute) && self.class.attribute_types[attribute].is_a?(ActiveRecord::Type::Serialized)
                  send("#{attribute}=", send(attribute))
                end
              end
            end
          end

          serialize name, JSON if options[:type] == :json
          serialize name, Hash if options[:type] == :hash

          attribute name, attribute_type

          define_method("#{name}=") do |message|
            original_message = message

            unless message.nil?
              case options[:type]
              when :boolean
                message = ActiveRecord::Type::Boolean.new.serialize(message)
                message = nil if message == "" # for Active Record < 5.2
                message = message ? "t" : "f" unless message.nil?
              when :date
                message = ActiveRecord::Type::Date.new.serialize(message)
                # strftime should be more stable than to_s(:db)
                message = message.strftime("%Y-%m-%d") unless message.nil?
              when :datetime
                message = ActiveRecord::Type::DateTime.new.serialize(message)
                message = nil unless message.respond_to?(:iso8601) # for Active Record < 5.2
                message = message.iso8601(9) unless message.nil?
              when :time
                message = ActiveRecord::Type::Time.new.serialize(message)
                message = nil unless message.respond_to?(:strftime)
                message = message.strftime("%H:%M:%S.%N") unless message.nil?
                message
              when :integer
                message = ActiveRecord::Type::Integer.new(limit: 8).serialize(message)
                message = 0 if message.nil?
                # signed 64-bit integer, big endian
                message = [message].pack("q>")
              when :float
                message = ActiveRecord::Type::Float.new.serialize(message)
                # double precision, big endian
                message = [message].pack("G") unless message.nil?
              when :string, :binary
                # do nothing
                # encrypt will convert to binary
              else
                type = self.class.attribute_types[name.to_s]
                if type.is_a?(ActiveRecord::Type::Serialized)
                  message = type.serialize(message)
                end
              end
            end

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

            super(original_message)
          end

          define_method(name) do
            message = super()

            unless message
              ciphertext = send(encrypted_attribute)
              message =
                if ciphertext.nil? || (ciphertext == "" && !options[:padding])
                  ciphertext
                else
                  ciphertext = Base64.decode64(ciphertext) if encode
                  Lockbox::Utils.build_box(self, options, self.class.table_name, encrypted_attribute).decrypt(ciphertext)
                end

              unless message.nil?
                case options[:type]
                when :boolean
                  message = message == "t"
                when :date
                  message = ActiveRecord::Type::Date.new.deserialize(message)
                when :datetime
                  message = ActiveRecord::Type::DateTime.new.deserialize(message)
                when :time
                  message = ActiveRecord::Type::Time.new.deserialize(message)
                when :integer
                  message = ActiveRecord::Type::Integer.new(limit: 8).deserialize(message.unpack("q>").first)
                when :float
                  message = ActiveRecord::Type::Float.new.deserialize(message.unpack("G").first)
                when :string
                  message.force_encoding(Encoding::UTF_8)
                when :binary
                  # do nothing
                  # decrypt returns binary string
                else
                  type = self.class.attribute_types[name.to_s]
                  if type.is_a?(ActiveRecord::Type::Serialized)
                    message = type.deserialize(message)
                  else
                    # default to string if not serialized
                    message.force_encoding(Encoding::UTF_8)
                  end
                end
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
            ciphertext = Base64.strict_encode64(ciphertext) if encode
            ciphertext
          end
        end
      end
    end
  end
end
