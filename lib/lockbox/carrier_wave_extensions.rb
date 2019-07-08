class Lockbox
  module CarrierWaveExtensions
    class FileIO < StringIO
      attr_accessor :original_filename
    end

    def encrypt(**options)
      class_eval do
        before :cache, :encrypt

        def encrypt(file)
          @file = CarrierWave::SanitizedFile.new(StringIO.new(lockbox.encrypt(file.read)))
        end

        def read
          r = super
          lockbox.decrypt(r) if r
        end

        def size
          read.bytesize
        end

        def rotate_encryption!
          io = FileIO.new(read)
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
            attribute =
              if mounted_as
                mounted_as.to_s
              else
                uploader = self
                while uploader.parent_version
                  uploader = uploader.parent_version
                end
                uploader.class.name.sub(/Uploader\z/, "").underscore
              end

            Utils.build_box(self, options, table, attribute)
          end
        end
      end
    end
  end
end

CarrierWave::Uploader::Base.extend(Lockbox::CarrierWaveExtensions)
