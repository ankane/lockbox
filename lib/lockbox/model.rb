module Lockbox
  module Model
    def has_encrypted(*attributes, **options)
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
      # when BigDecimal
      #   options[:type] = :decimal
      # end

      custom_type = options[:type].respond_to?(:serialize) && options[:type].respond_to?(:deserialize)
      valid_types = [nil, :string, :boolean, :date, :datetime, :time, :integer, :float, :decimal, :binary, :json, :hash, :array, :inet]
      raise ArgumentError, "Unknown type: #{options[:type]}" unless custom_type || valid_types.include?(options[:type])

      activerecord = defined?(ActiveRecord::Base) && self < ActiveRecord::Base
      raise ArgumentError, "Type not supported yet with Mongoid" if options[:type] && !activerecord

      raise ArgumentError, "No attributes specified" if attributes.empty?

      raise ArgumentError, "Cannot use key_attribute with multiple attributes" if options[:key_attribute] && attributes.size > 1

      original_options = options.dup

      attributes.each do |name|
        # per attribute options
        # TODO use a different name
        options = original_options.dup

        # add default options
        encrypted_attribute = options.delete(:encrypted_attribute) || "#{name}_ciphertext"

        # migrating
        original_name = name.to_sym
        name = "migrated_#{name}" if options[:migrating]

        name = name.to_sym

        options[:attribute] = name.to_s
        options[:encrypted_attribute] = encrypted_attribute
        options[:encode] = Lockbox.encode_attributes unless options.key?(:encode)

        encrypt_method_name = "generate_#{encrypted_attribute}"
        decrypt_method_name = "decrypt_#{encrypted_attribute}"

        class_eval do
          # Lockbox uses custom inspect
          # but this could be useful for other gems
          if activerecord
            # only add virtual attribute
            # need to use regexp since strings do partial matching
            # also, need to use += instead of <<
            self.filter_attributes += [/\A#{Regexp.escape(options[:attribute])}\z/]
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

            # use same approach as activerecord serialization
            def serializable_hash(options = nil)
              options = options.try(:dup) || {}

              options[:except] = Array(options[:except])
              options[:except] += self.class.lockbox_attributes.flat_map { |_, v| [v[:attribute], v[:encrypted_attribute]] }

              super(options)
            end

            # maintain order
            # replace ciphertext attributes w/ virtual attributes (filtered)
            def inspect
              lockbox_attributes = {}
              lockbox_encrypted_attributes = {}
              self.class.lockbox_attributes.each do |_, lockbox_attribute|
                lockbox_attributes[lockbox_attribute[:attribute]] = true
                lockbox_encrypted_attributes[lockbox_attribute[:encrypted_attribute]] = lockbox_attribute[:attribute]
              end

              inspection = []
              # use serializable_hash like Devise
              values = serializable_hash
              self.class.attribute_names.each do |k|
                next if !has_attribute?(k) || lockbox_attributes[k]

                # check for lockbox attribute
                if lockbox_encrypted_attributes[k]
                  # check if ciphertext attribute nil to avoid loading attribute
                  v = send(k).nil? ? "nil" : "[FILTERED]"
                  k = lockbox_encrypted_attributes[k]
                elsif values.key?(k)
                  v = respond_to?(:attribute_for_inspect) ? attribute_for_inspect(k) : values[k].inspect
                else
                  next
                end

                inspection << "#{k}: #{v}"
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
                  if has_attribute?(lockbox_attribute[:encrypted_attribute])
                    begin
                      send(lockbox_attribute[:attribute])
                    rescue ArgumentError => e
                      raise e if e.message != "No decryption key set"
                    end
                  end
                end

                # remove attributes that do not have a ciphertext attribute
                attributes = super
                self.class.lockbox_attributes.each do |k, lockbox_attribute|
                  if !attributes.include?(lockbox_attribute[:encrypted_attribute].to_s)
                    attributes.delete(k.to_s)
                    attributes.delete(lockbox_attribute[:attribute])
                  end
                end
                attributes
              end

              # remove attribute names that do not have a ciphertext attribute
              def attribute_names
                # hash preserves key order
                names_set = super.to_h { |v| [v, true] }
                self.class.lockbox_attributes.each do |k, lockbox_attribute|
                  if !names_set.include?(lockbox_attribute[:encrypted_attribute].to_s)
                    names_set.delete(k.to_s)
                    names_set.delete(lockbox_attribute[:attribute])
                  end
                end
                names_set.keys
              end

              # check the ciphertext attribute for encrypted attributes
              def has_attribute?(attr_name)
                attr_name = attr_name.to_s
                _, lockbox_attribute = self.class.lockbox_attributes.find { |_, la| la[:attribute] == attr_name }
                if lockbox_attribute
                  super(lockbox_attribute[:encrypted_attribute])
                else
                  super
                end
              end

              # needed for in-place modifications
              # assigned attributes are encrypted on assignment
              # and then again here
              def lockbox_sync_attributes
                self.class.lockbox_attributes.each do |_, lockbox_attribute|
                  attribute = lockbox_attribute[:attribute]

                  if attribute_changed_in_place?(attribute) || (send("#{attribute}_changed?") && !send("#{lockbox_attribute[:encrypted_attribute]}_changed?"))
                    send("#{attribute}=", send(attribute))
                  end
                end
              end

              # safety check
              [:_create_record, :_update_record].each do |method_name|
                unless private_method_defined?(method_name) || method_defined?(method_name)
                  raise Lockbox::Error, "Expected #{method_name} to be defined. Please report an issue."
                end
              end

              def _create_record(*)
                lockbox_sync_attributes
                super
              end

              def _update_record(*)
                lockbox_sync_attributes
                super
              end

              def [](attr_name)
                send(attr_name) if self.class.lockbox_attributes.any? { |_, la| la[:attribute] == attr_name.to_s }
                super
              end

              def update_columns(attributes)
                return super unless attributes.is_a?(Hash)

                # transform keys like Active Record
                attributes = attributes.transform_keys do |key|
                  n = key.to_s
                  self.class.attribute_aliases[n] || n
                end

                lockbox_attributes = self.class.lockbox_attributes.slice(*attributes.keys.map(&:to_sym))
                return super unless lockbox_attributes.any?

                attributes_to_set = {}

                lockbox_attributes.each do |key, lockbox_attribute|
                  attribute = key.to_s
                  # check read only
                  verify_readonly_attribute(attribute)

                  message = attributes[attribute]
                  attributes.delete(attribute) unless lockbox_attribute[:migrating]
                  encrypted_attribute = lockbox_attribute[:encrypted_attribute]
                  ciphertext = self.class.send("generate_#{encrypted_attribute}", message, context: self)
                  attributes[encrypted_attribute] = ciphertext
                  attributes_to_set[attribute] = message
                  attributes_to_set[lockbox_attribute[:attribute]] = message if lockbox_attribute[:migrating]
                end

                result = super(attributes)

                # same logic as Active Record
                # (although this happens before saving)
                attributes_to_set.each do |k, v|
                  if respond_to?(:write_attribute_without_type_cast, true)
                    write_attribute_without_type_cast(k, v)
                  elsif respond_to?(:raw_write_attribute, true)
                    raw_write_attribute(k, v)
                  else
                    @attributes.write_cast_value(k, v)
                    clear_attribute_change(k)
                  end
                end

                result
              end

              if ActiveRecord::VERSION::STRING.to_f >= 7.2
                def self.insert(attributes, **options)
                  super(lockbox_map_record_attributes(attributes), **options)
                end

                def self.insert!(attributes, **options)
                  super(lockbox_map_record_attributes(attributes), **options)
                end

                def self.upsert(attributes, **options)
                  super(lockbox_map_record_attributes(attributes, check_readonly: true), **options)
                end
              end

              def self.insert_all(attributes, **options)
                super(lockbox_map_attributes(attributes), **options)
              end

              def self.insert_all!(attributes, **options)
                super(lockbox_map_attributes(attributes), **options)
              end

              def self.upsert_all(attributes, **options)
                super(lockbox_map_attributes(attributes, check_readonly: true), **options)
              end

              # private
              # does not try to handle :returning option for simplicity
              def self.lockbox_map_attributes(records, check_readonly: false)
                return records unless records.is_a?(Array)

                records.map do |attributes|
                  lockbox_map_record_attributes(attributes, check_readonly: false)
                end
              end

              # private
              def self.lockbox_map_record_attributes(attributes, check_readonly: false)
                return attributes unless attributes.is_a?(Hash)

                # transform keys like Active Record
                attributes = attributes.transform_keys do |key|
                  n = key.to_s
                  attribute_aliases[n] || n
                end

                lockbox_attributes = self.lockbox_attributes.slice(*attributes.keys.map(&:to_sym))
                lockbox_attributes.each do |key, lockbox_attribute|
                  attribute = key.to_s
                  # check read only
                  # users should mark both plaintext and ciphertext columns
                  if check_readonly && readonly_attributes.include?(attribute) && !readonly_attributes.include?(lockbox_attribute[:encrypted_attribute].to_s)
                    warn "[lockbox] WARNING: Mark attribute as readonly: #{lockbox_attribute[:encrypted_attribute]}"
                  end

                  message = attributes[attribute]
                  attributes.delete(attribute) unless lockbox_attribute[:migrating]
                  encrypted_attribute = lockbox_attribute[:encrypted_attribute]
                  ciphertext = send("generate_#{encrypted_attribute}", message)
                  attributes[encrypted_attribute] = ciphertext
                end

                attributes
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
          raise "Multiple encrypted attributes use the same column: #{encrypted_attribute}" if lockbox_attributes.any? { |_, v| v[:encrypted_attribute] == encrypted_attribute }
          @lockbox_attributes[original_name] = options

          if activerecord
            # warn on store attributes
            if stored_attributes.any? { |k, v| v.include?(name) }
              warn "[lockbox] WARNING: encrypting store accessors is not supported. Encrypt the column instead."
            end

            # warn on default attributes
            if ActiveRecord::VERSION::STRING.to_f >= 7.2
              # TODO improve
              if pending_attribute_modifications.any? { |v| v.is_a?(ActiveModel::AttributeRegistration::ClassMethods::PendingDefault) && v.name == name.to_s }
                warn "[lockbox] WARNING: attributes with `:default` option are not supported. Use `after_initialize` instead."
              end
            elsif attributes_to_define_after_schema_loads.key?(name.to_s)
              opt = attributes_to_define_after_schema_loads[name.to_s][1]

              # not ideal, since NO_DEFAULT_PROVIDED is private
              has_default = opt != ActiveRecord::Attributes::ClassMethods.const_get(:NO_DEFAULT_PROVIDED)

              if has_default
                warn "[lockbox] WARNING: attributes with `:default` option are not supported. Use `after_initialize` instead."
              end
            end

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

              if ActiveRecord::VERSION::STRING.to_f >= 7.1
                case options[:type]
                when :json
                  serialize name, coder: JSON
                when :hash
                  serialize name, type: Hash, coder: default_column_serializer || YAML
                when :array
                  serialize name, type: Array, coder: default_column_serializer || YAML
                end
              else
                case options[:type]
                when :json
                  serialize name, JSON
                when :hash
                  serialize name, Hash
                when :array
                  serialize name, Array
                end
              end
            elsif ActiveRecord::VERSION::STRING.to_f >= 7.2
              decorate_attributes([name]) do |attr_name, cast_type|
                if cast_type.instance_of?(ActiveRecord::Type::Value)
                  original_type = pending_attribute_modifications.find { |v| v.is_a?(ActiveModel::AttributeRegistration::ClassMethods::PendingType) && v.name == original_name.to_s && !v.type.nil? }&.type
                  if original_type
                    original_type
                  elsif options[:migrating]
                    cast_type
                  else
                    ActiveRecord::Type::String.new
                  end
                elsif cast_type.is_a?(ActiveRecord::Type::Serialized) && cast_type.subtype.instance_of?(ActiveModel::Type::Value)
                  # hack to set string type after serialize
                  # otherwise, type gets set to ActiveModel::Type::Value
                  # which always returns false for changed_in_place?
                  ActiveRecord::Type::Serialized.new(ActiveRecord::Type::String.new, cast_type.coder)
                else
                  cast_type
                end
              end
            elsif !attributes_to_define_after_schema_loads.key?(name.to_s)
              # when migrating it's best to specify the type directly
              # however, we can try to use the original type if its already defined
              if attributes_to_define_after_schema_loads.key?(original_name.to_s)
                attribute name, attributes_to_define_after_schema_loads[original_name.to_s].first
              elsif options[:migrating]
                # we use the original attribute for serialization in the encrypt and decrypt methods
                # so we can use a generic value here
                attribute name, ActiveRecord::Type::Value.new
              else
                attribute name, :string
              end
            elsif attributes_to_define_after_schema_loads[name.to_s].first.is_a?(Proc)
              # hack for Active Record 6.1+ to set string type after serialize
              # otherwise, type gets set to ActiveModel::Type::Value
              # which always returns false for changed_in_place?
              # earlier versions of Active Record take the previous code path
              attribute_type = attributes_to_define_after_schema_loads[name.to_s].first.call(nil)
              if attribute_type.is_a?(ActiveRecord::Type::Serialized) && attribute_type.subtype.nil?
                attribute name, ActiveRecord::Type::Serialized.new(ActiveRecord::Type::String.new, attribute_type.coder)
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

            define_method("#{name}_in_database") do
              send(name) # writes attribute when not already set
              super()
            end

            define_method("#{name}?") do
              # uses public_send, so we don't need to preload attribute
              query_attribute(name)
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

            define_method("#{name}?") do
              send("#{encrypted_attribute}?")
            end
          end

          define_method("#{name}=") do |message|
            # decrypt first for dirty tracking
            # don't raise error if can't decrypt previous
            # don't try to decrypt if no decryption key given
            begin
              send(name)
            rescue Lockbox::DecryptionError
              warn "[lockbox] Decrypting previous value failed"
            rescue ArgumentError => e
              raise e if e.message != "No decryption key set"
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

              # keep original message for empty hashes and arrays
              unless ciphertext.nil?
                message = self.class.send(decrypt_method_name, ciphertext, context: self)
              end

              if activerecord
                # set previous attribute so changes populate correctly
                # it's fine if this is set on future decryptions (as is the case when message is nil)
                # as only the first value is loaded into changes
                @attributes[name.to_s].instance_variable_set("@value_before_type_cast", message)

                # cache
                # decrypt method does type casting
                if respond_to?(:write_attribute_without_type_cast, true)
                  write_attribute_without_type_cast(name.to_s, message) if !@attributes.frozen?
                elsif respond_to?(:raw_write_attribute, true)
                  raw_write_attribute(name, message) if !@attributes.frozen?
                else
                  if !@attributes.frozen?
                    @attributes.write_cast_value(name.to_s, message)
                    clear_attribute_change(name)
                  end
                end

                # ensure same object is returned as next call
                message = super()
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
              case options[:type]
              when :boolean
                message = ActiveRecord::Type::Boolean.new.serialize(message)
                message = message ? "t" : "f" unless message.nil?
              when :date
                message = ActiveRecord::Type::Date.new.serialize(message)
                # strftime should be more stable than to_s(:db)
                message = message.strftime("%Y-%m-%d") unless message.nil?
              when :datetime
                message = ActiveRecord::Type::DateTime.new.serialize(message)
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
              when :decimal
                message = ActiveRecord::Type::Decimal.new.serialize(message)
                # Postgres stores 4 decimal digits in 2 bytes
                # plus 3 to 8 bytes of overhead
                # but use string for simplicity
                message = message.to_s("F") unless message.nil?
              when :inet
                unless message.nil?
                  ip = message.is_a?(IPAddr) ? message : (IPAddr.new(message) rescue nil)
                  # same format as Postgres, with ipv4 padded to 16 bytes
                  # family, netmask, ip
                  # return nil for invalid IP like Active Record
                  message = ip ? [ip.ipv4? ? 0 : 1, ip.prefix, ip.hton].pack("CCa16") : nil
                end
              when :string, :binary
                # do nothing
                # encrypt will convert to binary
              else
                # use original name for serialized attributes if no type specified
                type = (try(:attribute_types) || {})[(options[:type] ? name : original_name).to_s]
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
                message = ActiveRecord::Type::Integer.new(limit: 8).deserialize(message.unpack1("q>"))
              when :float
                message = ActiveRecord::Type::Float.new.deserialize(message.unpack1("G"))
              when :decimal
                message = ActiveRecord::Type::Decimal.new.deserialize(message)
              when :string
                message.force_encoding(Encoding::UTF_8)
              when :binary
                # do nothing
                # decrypt returns binary string
              when :inet
                family, prefix, addr = message.unpack("CCa16")
                len = family == 0 ? 4 : 16
                message = IPAddr.new_ntoh(addr.first(len))
                message.prefix = prefix
              else
                # use original name for serialized attributes if no type specified
                type = (try(:attribute_types) || {})[(options[:type] ? name : original_name).to_s]
                # for Action Text
                if activerecord && type.is_a?(ActiveRecord::Type::Serialized) && defined?(ActionText::Content) && type.coder == ActionText::Content
                  message.force_encoding(Encoding::UTF_8)
                end
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
