# ideally encrypt and decrypt would happen at the blob/service level
# however, there isn't really a great place to define encryption settings there
# instead, we encrypt and decrypt at the attachment level,
# and we define encryption settings at the model level
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

      def rebuild_attachable(attachment)
        {
          io: StringIO.new(attachment.download),
          filename: attachment.filename,
          content_type: attachment.content_type
        }
      end
    end

    module AttachedOne
      if ActiveStorage::VERSION::MAJOR < 6
        def attach(attachable)
          attachable = encrypt_attachable(attachable) if encrypted?
          super(attachable)
        end
      end

      def rotate_encryption!
        raise "Not encrypted" unless encrypted?

        attach(rebuild_attachable(self)) if attached?

        true
      end
    end

    module AttachedMany
      if ActiveStorage::VERSION::MAJOR < 6
        def attach(*attachables)
          if encrypted?
            attachables =
              attachables.flatten.collect do |attachable|
                encrypt_attachable(attachable)
              end
          end

          super(attachables)
        end
      end

      def rotate_encryption!
        raise "Not encrypted" unless encrypted?

        # must call to_a - do not change
        previous_attachments = attachments.to_a

        attachables =
          previous_attachments.map do |attachment|
            rebuild_attachable(attachment)
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
        attachable = Lockbox::Utils.encrypt_attachable(record, name, attachable) if Lockbox::Utils.encrypted?(record, name) && !attachable.is_a?(ActiveStorage::Blob)
        super(name, record, attachable)
      end
    end

    module Attachment
      extend ActiveSupport::Concern

      def download
        result = super

        options = Utils.encrypted_options(record, name)
        if options
          result = Utils.build_box(record, options, record.class.table_name, name).decrypt(result)
        end

        result
      end

      if ActiveStorage::VERSION::MAJOR >= 6
        def open(**options)
          blob.open(**options) do |file|
            options = Utils.encrypted_options(record, name)
            if options
              result = file.read
              file.rewind
              # truncate may not be available on all platforms
              # according to the Ruby docs
              # may need to create a new temp file instead
              file.truncate(0)
              file.write(Utils.build_box(record, options, record.class.table_name, name).decrypt(result))
              file.rewind
            end

            yield file
          end
        end
      end

      def mark_analyzed
        if Utils.encrypted_options(record, name)
          blob.update!(metadata: blob.metadata.merge(analyzed: true))
        end
      end

      included do
        after_save :mark_analyzed
      end
    end

    module Blob
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
