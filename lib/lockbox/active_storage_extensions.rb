# Ideally encryption and decryption would happen at the blob/service level.
# However, Active Storage < 6.1 only supports a single service (per environment).
# This means all attachments need to be encrypted or none of them,
# which is often not practical.
#
# Active Storage 6.1 adds support for multiple services, which changes this.
# We could have a Lockbox service:
#
# lockbox:
#   service: Lockbox
#   backend: local    # delegate to another service, like mirror service
#   key:     ...      # Lockbox options
#
# However, the checksum is computed *and stored on the blob*
# before the file is passed to the service.
# We don't want the MD5 checksum of the plaintext stored in the database.
#
# Instead, we encrypt and decrypt at the attachment level,
# and we define encryption settings at the model level.
module Lockbox
  module ActiveStorageExtensions
    module Attached
      protected

      def encrypted?
        # could use record_type directly
        # but record should already be loaded most of the time
        Utils.encrypted?(record, name)
      end

      def encrypt_attachable(attachable)
        Utils.encrypt_attachable(record, name, attachable)
      end
    end

    module AttachedOne
      def rotate_encryption!
        raise "Not encrypted" unless encrypted?

        attach(Utils.rebuild_attachable(self)) if attached?

        true
      end
    end

    module AttachedMany
      def rotate_encryption!
        raise "Not encrypted" unless encrypted?

        # must call to_a - do not change
        previous_attachments = attachments.to_a

        attachables =
          previous_attachments.map do |attachment|
            Utils.rebuild_attachable(attachment)
          end

        ActiveStorage::Attachment.transaction do
          attach(attachables)
          previous_attachments.each(&:purge)
        end

        attachments.reload

        true
      end
    end

    module CreateOne
      def initialize(name, record, attachable)
        # this won't encrypt existing blobs
        # ideally we'd check metadata for the encrypted flag
        # and disallow unencrypted blobs
        # since they'll raise an error on decryption
        # but earlier versions of Lockbox won't have it
        attachable = Lockbox::Utils.encrypt_attachable(record, name, attachable) if Lockbox::Utils.encrypted?(record, name) && !attachable.is_a?(ActiveStorage::Blob)
        super(name, record, attachable)
      end
    end

    module Attachment
      def download
        result = super

        options = Utils.encrypted_options(record, name)
        # only trust the metadata when migrating
        # as earlier versions of Lockbox won't have it
        # and it's not a good practice to trust modifiable data
        encrypted = options && (!options[:migrating] || blob.metadata["encrypted"])
        if encrypted
          result = Utils.decrypt_result(record, name, options, result)
        end

        result
      end

      def variant(*args)
        raise Lockbox::Error, "Variant not supported for encrypted files" if Utils.encrypted_options(record, name)
        super
      end

      def preview(*args)
        raise Lockbox::Error, "Preview not supported for encrypted files" if Utils.encrypted_options(record, name)
        super
      end

      if ActiveStorage::VERSION::STRING.to_f == 7.1 && ActiveStorage.version >= "7.1.4"
        def transform_variants_later
          blob.instance_variable_set(:@lockbox_encrypted, true) if Utils.encrypted_options(record, name)
          super
        end
      end

      def open(**options)
        blob.open(**options) do |file|
          options = Utils.encrypted_options(record, name)
          # only trust the metadata when migrating
          # as earlier versions of Lockbox won't have it
          # and it's not a good practice to trust modifiable data
          encrypted = options && (!options[:migrating] || blob.metadata["encrypted"])
          if encrypted
            result = Utils.decrypt_result(record, name, options, file.read)
            file.rewind
            # truncate may not be available on all platforms
            # according to the Ruby docs
            # may need to create a new temp file instead
            file.truncate(0)
            file.write(result)
            file.rewind
          end

          yield file
        end
      end
    end

    module Blob
      if ActiveStorage::VERSION::STRING.to_f == 7.1 && ActiveStorage.version >= "7.1.4"
        def preview_image_needed_before_processing_variants?
          !instance_variable_defined?(:@lockbox_encrypted) && super
        end
      end

      private

      def extract_content_type(io)
        if io.is_a?(Lockbox::IO) && io.extracted_content_type
          io.extracted_content_type
        else
          super
        end
      end
    end
  end
end
