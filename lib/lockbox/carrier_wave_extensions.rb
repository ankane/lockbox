class Lockbox
  module CarrierWaveExtensions
    class FileIO < StringIO
      attr_accessor :original_filename
    end

    def kms_encrypt(kms_key_id:, **options)
      require "aws-sdk-kms"
      require "base64"

      encrypt

      class_eval do
        define_method :encryption_context do
          {
            bucket: aws_bucket,
            key: identifier
          }
        end unless method_defined?(:encryption_context)

        private

        def ensure_carrierwave_aws
          unless defined?(CarrierWave::Storage::AWS) && storage.is_a?(CarrierWave::Storage::AWS)
            raise ArgumentError, "Requires :aws storage"
          end
        end

        def kms_client
          @kms_client ||= Aws::KMS::Client.new
        end

        define_method :encrypt_options do
          ensure_carrierwave_aws

          key = SecureRandom.random_bytes(32)

          aws_options = {
            key_id: kms_key_id,
            plaintext: key,
            encryption_context: encryption_context
          }
          encrypted_key = kms_client.encrypt(aws_options).ciphertext_blob

          @encrypted_key = Base64.strict_encode64(encrypted_key)

          options.merge(key: key)
        end

        define_method :decrypt_options do
          ensure_carrierwave_aws

          # metadata is returned in GetObject response
          # but no easy way to access it w/ CarrierWave AWS
          # as a result, this performs an extra HeadObject request
          metadata = file.file.metadata
          encrypted_key = Base64.decode64(metadata["encrypted-key"])

          aws_options = {
            ciphertext_blob: encrypted_key,
            encryption_context: encryption_context
          }
          key = kms_client.decrypt(aws_options).plaintext

          options.merge(key: key)
        end
      end

      # preserve write options
      m = Module.new do
        def aws_write_options
          options = super || {}
          options[:metadata] ||= options.delete(:metadata) || {}
          options[:metadata]["encrypted-key"] = @encrypted_key
          options
        end
      end

      prepend(m)
    end

    def encrypt(**options)
      class_eval do
        before :cache, :encrypt

        def encrypt(file)
          @file = CarrierWave::SanitizedFile.new(StringIO.new(Utils.build_box(self, encrypt_options).encrypt(file.read)))
        end

        def read
          r = super
          Utils.build_box(self, decrypt_options).decrypt(r) if r
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

        define_method :encrypt_options do
          options
        end unless method_defined?(:encrypt_options)

        define_method :decrypt_options do
          options
        end unless method_defined?(:decrypt_options)
      end
    end
  end
end

CarrierWave::Uploader::Base.extend(Lockbox::CarrierWaveExtensions)
