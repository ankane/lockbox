module Lockbox
  module Model
    def encrypts(*attributes, **options)
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
      # when Array
      #   options[:type] = :array
      # when String
      #   options[:type] = :string
      # when Integer
      #   options[:type] = :integer
      # when Float
      #   options[:type] = :float
      # end

      custom_type = options[:type].respond_to?(:serialize) && options[:type].respond_to?(:deserialize)
      raise ArgumentError, "Unknown type: #{options[:type]}" unless custom_type || [nil, :string, :boolean, :date, :datetime, :time, :integer, :float, :binary, :json, :hash, :array].include?(options[:type])

      activerecord = defined?(ActiveRecord::Base) && self < ActiveRecord::Base
      raise ArgumentError, "Type not supported yet with Mongoid" if options[:type] && !activerecord

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
        options[:encode] = true unless options.key?(:encode)

        encrypt_method_name = "generate_#{encrypted_attribute}"
        decrypt_method_name = "decrypt_#{encrypted_attribute}"

        class_eval do
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

            if activerecord
              # TODO wrap in module?
              def attributes
                # load attributes
                # essentially a no-op if already loaded
                # an exception is thrown if decryption fails
                self.class.lockbox_attributes.each do |_, lockbox_attribute|
                  # it is possible that the encrypted attribute is not loaded, eg.
                  # if the record was fetched partially (`User.select(:id).first`).
                  # accessing a not loaded attribute raises an `ActiveModel::MissingAttributeError`.
                  # `respond_to?` actually returns `false` in activerecord if an attribute was not
                  # loaded, so we do not try to decrypt it in this case.
                  next unless respond_to?(lockbox_attribute[:encrypted_attribute])

                  send(lockbox_attribute[:attribute])
                end
                super
              end

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
            else
              def reload
                self.class.lockbox_attributes.each do |_, v|
                  instance_variable_set("@#{v[:attribute]}", nil)
                end
                super
              end
            end
          end

          raise "Duplicate encrypted attribute: #{original_name}" if lockbox_attributes[original_name]
          @lockbox_attributes[original_name] = options

          if activerecord
            # preference:
            # 1. type option
            # 2. existing virtual attribute
            # 3. default to string (which can later be overridden)
            if options[:type]
              attribute_type =
                case options[:type]
                when :json, :hash, :array
                  :string
                when :integer
                  ActiveModel::Type::Integer.new(limit: 8)
                else
                  options[:type]
                end

              attribute name, attribute_type

              serialize name, JSON if options[:type] == :json
              serialize name, Hash if options[:type] == :hash
              serialize name, Array if options[:type] == :array
            elsif !attributes_to_define_after_schema_loads.key?(name.to_s)
              # when migrating it's best to specify the type directly
              # however, we can try to use the original type if its already defined
              if attributes_to_define_after_schema_loads.key?(original_name.to_s)
                attribute name, attributes_to_define_after_schema_loads[original_name.to_s].first
              else
                attribute name, :string
              end
            end

            define_method("#{name}_was") do
              send(name) # writes attribute when not already set
              super()
            end

            # restore ciphertext as well
            define_method("restore_#{name}!") do
              super()
              send("restore_#{encrypted_attribute}!")
            end

            if ActiveRecord::VERSION::STRING >= "5.1"
              define_method("#{name}_in_database") do
                send(name) # writes attribute when not already set
                super()
              end
            end
          else
            # keep this module dead simple
            # Mongoid uses changed_attributes to calculate keys to update
            # so we shouldn't mess with it
            m = Module.new do
              define_method("#{name}=") do |val|
                instance_variable_set("@#{name}", val)
              end

              define_method(name) do
                instance_variable_get("@#{name}")
              end
            end

            include m

            alias_method "#{name}_changed?", "#{encrypted_attribute}_changed?"

            define_method "#{name}_was" do
              ciphertext = send("#{encrypted_attribute}_was")
              self.class.send(decrypt_method_name, ciphertext, context: self)
            end

            define_method "#{name}_change" do
              ciphertexts = send("#{encrypted_attribute}_change")
              ciphertexts.map { |v| self.class.send(decrypt_method_name, v, context: self) } if ciphertexts
            end

            define_method "reset_#{name}!" do
              instance_variable_set("@#{name}", nil)
              send("reset_#{encrypted_attribute}!")
              send(name)
            end

            define_method "reset_#{name}_to_default!" do
              instance_variable_set("@#{name}", nil)
              send("reset_#{encrypted_attribute}_to_default!")
              send(name)
            end
          end

          define_method("#{name}?") do
            send("#{encrypted_attribute}?")
          end

          define_method("#{name}=") do |message|
            # decrypt first for dirty tracking
            # don't raise error if can't decrypt previous
            begin
              send(name)
            rescue Lockbox::DecryptionError
              # this is expected for hybrid cryptography
              warn "[lockbox] Decrypting previous value failed" unless options[:algorithm] == "hybrid"
              nil
            end

            send("lockbox_direct_#{name}=", message)

            # warn every time, as this should be addressed
            # maybe throw an error in the future
            if !options[:migrating]
              if activerecord
                if self.class.columns_hash.key?(name.to_s)
                  warn "[lockbox] WARNING: Unencrypted column with same name: #{name}. Set `ignored_columns` or remove it to protect the data."
                end
              else
                if self.class.fields.key?(name.to_s)
                  warn "[lockbox] WARNING: Unencrypted field with same name: #{name}. Remove it to protect the data."
                end
              end
            end

            super(message)
          end

          # separate method for setting directly
          # used to skip blind indexes for key rotation
          define_method("lockbox_direct_#{name}=") do |message|
            ciphertext = self.class.send(encrypt_method_name, message, context: self)
            send("#{encrypted_attribute}=", ciphertext)
          end
          private :"lockbox_direct_#{name}="

          define_method(name) do
            message = super()

            # possibly keep track of decrypted attributes directly in the future
            # Hash serializer returns {} when nil, Array serializer returns [] when nil
            # check for this explicitly as a layer of safety
            if message.nil? || ((message == {} || message == []) && activerecord && @attributes[name.to_s].value_before_type_cast.nil?)
              ciphertext = send(encrypted_attribute)
              message = self.class.send(decrypt_method_name, ciphertext, context: self)

              if activerecord
                # set previous attribute so changes populate correctly
                # it's fine if this is set on future decryptions (as is the case when message is nil)
                # as only the first value is loaded into changes
                @attributes[name.to_s].instance_variable_set("@value_before_type_cast", message)

                # cache
                # decrypt method does type casting
                if respond_to?(:write_attribute_without_type_cast, true)
                  write_attribute_without_type_cast(name, message) if !@attributes.frozen?
                else
                  raw_write_attribute(name, message) if !@attributes.frozen?
                end
              else
                instance_variable_set("@#{name}", message)
              end
            end

            message
          end

          # for fixtures
          define_singleton_method encrypt_method_name do |message, **opts|
            table = activerecord ? table_name : collection_name.to_s

            unless message.nil?
              # TODO use attribute type class in 0.5.0
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
              Lockbox::Utils.build_box(opts[:context], options, table, encrypted_attribute).encrypt(message)
            end
          end

          define_singleton_method decrypt_method_name do |ciphertext, **opts|
            message =
              if ciphertext.nil? || (ciphertext == "" && !options[:padding])
                ciphertext
              else
                table = activerecord ? table_name : collection_name.to_s
                Lockbox::Utils.build_box(opts[:context], options, table, encrypted_attribute).decrypt(ciphertext)
              end

            unless message.nil?
              # TODO use attribute type class in 0.5.0
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
                type = (try(:attribute_types) || {})[name.to_s]
                message = type.deserialize(message) if type
                message.force_encoding(Encoding::UTF_8) if !type || type.is_a?(ActiveModel::Type::String)
              end
            end

            message
          end

          if options[:migrating]
            # TODO reuse module
            m = Module.new do
              define_method "#{original_name}=" do |value|
                result = super(value)
                send("#{name}=", send(original_name))
                result
              end

              unless activerecord
                define_method "reset_#{original_name}!" do
                  result = super()
                  send("#{name}=", send(original_name))
                  result
                end
              end
            end
            prepend m
          end
        end
      end
    end

    module Attached
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
    end
  end
end
