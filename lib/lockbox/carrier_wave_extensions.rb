module Lockbox
  module CarrierWaveExtensions
    def encrypt(**options)
      class_eval do
        # uses same hook as process (before cache)
        # processing can be disabled, so better to keep separate
        before :cache, :encrypt

        define_singleton_method :lockbox_options do
          options
        end

        def encrypt(file)
          # safety check
          # see CarrierWave::Uploader::Cache#cache!
          raise Lockbox::Error, "Expected files to be equal. Please report an issue." unless file && @file && file == @file

          # processors in CarrierWave move updated file to current_path
          # however, this causes versions to use the processed file
          # we only want to change the file for the current version
          @file = CarrierWave::SanitizedFile.new(lockbox_notify("encrypt_file") { lockbox.encrypt_io(file) })
        end

        # TODO safe to memoize?
        def read
          r = super
          lockbox_notify("decrypt_file") { lockbox.decrypt(r) } if r
        end

        # use size of plaintext since read and content type use plaintext
        def size
          read.bytesize
        end

        def content_type
          if CarrierWave::VERSION.to_i >= 2
            # based on CarrierWave::SanitizedFile#mime_magic_content_type
            MimeMagic.by_magic(read).try(:type) || "invalid/invalid"
          else
            # uses filename
            super
          end
        end

        # disable processing since already processed
        def rotate_encryption!
          io = Lockbox::IO.new(read)
          io.original_filename = file.filename
          previous_value = enable_processing
          begin
            self.enable_processing = false
            store!(io)
          ensure
            self.enable_processing = previous_value
          end
        end

        private

        define_method :lockbox do
          @lockbox ||= begin
            table = model ? model.class.table_name : "_uploader"
            attribute = lockbox_name

            Utils.build_box(self, options, table, attribute)
          end
        end

        # for mounted uploaders, use mounted name
        # for others, use uploader name
        def lockbox_name
          if mounted_as
            mounted_as.to_s
          else
            uploader = self
            while uploader.parent_version
              uploader = uploader.parent_version
            end
            uploader.class.name.sub(/Uploader\z/, "").underscore
          end
        end

        # Active Support notifications so it's easier
        # to see when files are encrypted and decrypted
        def lockbox_notify(type)
          if defined?(ActiveSupport::Notifications)
            name = lockbox_name

            # get version
            version, _ = parent_version && parent_version.versions.find { |k, v| v == self }
            name = "#{name} #{version} version" if version

            ActiveSupport::Notifications.instrument("#{type}.lockbox", {name: name}) do
              yield
            end
          else
            yield
          end
        end
      end
    end
  end
end

if CarrierWave::VERSION.to_i > 2
  raise "CarrierWave version (#{CarrierWave::VERSION}) not supported in this version of Lockbox (#{Lockbox::VERSION})"
elsif CarrierWave::VERSION.to_i < 1
  # TODO raise error in 0.7.0
  warn "CarrierWave version (#{CarrierWave::VERSION}) not supported in this version of Lockbox (#{Lockbox::VERSION})"
end

CarrierWave::Uploader::Base.extend(Lockbox::CarrierWaveExtensions)
