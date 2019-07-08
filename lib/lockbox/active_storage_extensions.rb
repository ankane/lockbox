# ideally encrypt and decrypt would happen at the blob/service level
# however, there isn't really a great place to define encryption settings there
# instead, we encrypt and decrypt at the attachment level,
# and we define encryption settings at the model level
class Lockbox
  module ActiveStorageExtensions
    module Attached
      protected

      def encrypted?
        # could use record_type directly
        # but record should already be loaded most of the time
        !Utils.encrypted_options(record, name).nil?
      end

      def encrypt_attachable(attachable)
        options = Utils.encrypted_options(record, name)
        box = Utils.build_box(record, options, record.class.table_name, name)

        case attachable
        when ActiveStorage::Blob
          raise NotImplementedError, "Not supported"
        when ActionDispatch::Http::UploadedFile, Rack::Test::UploadedFile
          attachable = {
            io: StringIO.new(box.encrypt(attachable.read)),
            filename: attachable.original_filename,
            content_type: attachable.content_type
          }
        when Hash
          attachable = {
            io: StringIO.new(box.encrypt(attachable[:io].read)),
            filename: attachable[:filename],
            content_type: attachable[:content_type]
          }
        when String
          raise NotImplementedError, "Not supported"
        else
          nil
        end

        attachable
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
      def attach(attachable)
        attachable = encrypt_attachable(attachable) if encrypted?
        super(attachable)
      end

      def rotate_encryption!
        raise "Not encrypted" unless encrypted?

        attach(rebuild_attachable(self)) if attached?

        true
      end
    end

    module AttachedMany
      def attach(*attachables)
        if encrypted?
          attachables =
            attachables.flatten.collect do |attachable|
              encrypt_attachable(attachable)
            end
        end

        super(attachables)
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

      def mark_analyzed
        if Utils.encrypted_options(record, name)
          blob.update!(metadata: blob.metadata.merge(analyzed: true))
        end
      end

      included do
        after_save :mark_analyzed
      end
    end
  end
end
