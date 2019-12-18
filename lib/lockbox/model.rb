module Lockbox
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

          if @lockbox_attachments.empty?
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

      custom_type = options[:type].respond_to?(:serialize) && options[:type].respond_to?(:deserialize)
      raise ArgumentError, "Unknown type: #{options[:type]}" unless custom_type || [nil, :string, :boolean, :date, :datetime, :time, :integer, :float, :binary, :json, :hash].include?(options[:type])

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

          if @lockbox_attributes.empty?
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
            # use same approach as activerecord serialization
            def serializable_hash(options = nil)
              options = options.try(:dup) || {}

              options[:except] = Array(options[:except])
              options[:except] += self.class.lockbox_attributes.flat_map { |_, v| [v[:attribute], v[:encrypted_attribute]] }

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

            if defined?(Mongoid::Document) && included_modules.include?(Mongoid::Document)
              def reload
                self.class.lockbox_attributes.each do |_, v|
                  instance_variable_set("@#{v[:attribute]}", nil)
                end
                super
              end
            else
              # needed for in-place modifications
              # assigned attributes are encrypted on assignment
              # and then again here
              before_save do
                self.class.lockbox_attributes.each do |_, lockbox_attribute|
                  attribute = lockbox_attribute[:attribute]

                  if attribute_changed_in_place?(attribute)
                    send("#{attribute}=", send(attribute))
                  end
                end
              end
            end
          end

          serialize name, JSON if options[:type] == :json
          serialize name, Hash if options[:type] == :hash

          if respond_to?(:attribute)
            # preference:
            # 1. type option
            # 2. existing virtual attribute
            # 3. default to string (which can later be overridden)
            if options[:type]
              attribute_type =
                case options[:type]
                when :json, :hash
                  :string
                when :integer
                  ActiveModel::Type::Integer.new(limit: 8)
                else
                  options[:type]
                end

              attribute name, attribute_type
            elsif !attributes_to_define_after_schema_loads.key?(name.to_s)
              attribute name, :string
            end

            define_method("#{name}?") do
              send("#{encrypted_attribute}?")
            end

            define_method("#{name}_was") do
              send(name) # writes attribute when not already set
              super()
            end

            if ActiveRecord::VERSION::STRING >= "5.1"
              define_method("#{name}_in_database") do
                send(name) # writes attribute when not already set
                super()
              end
            end
          else
            m = Module.new do
              define_method("#{name}=") do |val|
                prev_val = instance_variable_get("@#{name}")

                unless val == prev_val
                  # custom attribute_will_change! method
                  unless changed_attributes.key?(name.to_s)
                    changed_attributes[name.to_s] = prev_val.__deep_copy__
                  end
                end

                instance_variable_set("@#{name}", val)
              end

              define_method(name) do
                instance_variable_get("@#{name}")
              end
            end

            include m

            alias_method "#{name}_changed?", "#{encrypted_attribute}_changed?"

            define_method "#{name}_was" do
              attribute_was(name.to_s)
            end
          end

          define_method("#{name}=") do |message|
            original_message = message

            # decrypt first for dirty tracking
            # don't raise error if can't decrypt previous
            begin
              send(name)
            rescue Lockbox::DecryptionError
              nil
            end

            # set ciphertext
            ciphertext = self.class.send(class_method_name, message, context: self)
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
                  table = self.class.respond_to?(:table_name) ? self.class.table_name : self.class.collection_name.to_s
                  Lockbox::Utils.build_box(self, options, table, encrypted_attribute).decrypt(ciphertext)
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
                  type = (self.class.try(:attribute_types) || {})[name.to_s]
                  message = type.deserialize(message) if type
                  message.force_encoding(Encoding::UTF_8) if !type || type.is_a?(ActiveModel::Type::String)
                end
              end

              # set previous attribute on first decrypt
              @attributes[name.to_s].instance_variable_set("@value_before_type_cast", message) if @attributes[name.to_s]

              # cache
              if respond_to?(:_write_attribute, true)
                _write_attribute(name, message) if !@attributes.frozen?
              elsif respond_to?(:raw_write_attribute)
                raw_write_attribute(name, message) if !@attributes.frozen?
              else
                instance_variable_set("@#{name}", message)
              end
            end

            message
          end

          # for fixtures
          define_singleton_method class_method_name do |message, **opts|
            table = respond_to?(:table_name) ? table_name : collection_name.to_s

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
                type = (try(:attribute_types) || {})[name.to_s]
                message = type.serialize(message) if type
              end
            end

            if message.nil? || (message == "" && !options[:padding])
              message
            else
              ciphertext = Lockbox::Utils.build_box(opts[:context], options, table, encrypted_attribute).encrypt(message)
              ciphertext = Base64.strict_encode64(ciphertext) if encode
              ciphertext
            end
          end
        end
      end
    end
  end
end
