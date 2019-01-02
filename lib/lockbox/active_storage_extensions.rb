class Lockbox
  module ActiveStorageExtensions
    module Attached
      protected

      def encrypted?
        # could use record_type directly
        # but record should already be loaded most of the time
        Utils.encrypted_options(record, name).present?
      end

      def encrypt_attachable(attachable)
        options = Utils.encrypted_options(record, name)
        box = Utils.build_box(record, options)

        case attachable
        when ActiveStorage::Blob
          raise NotImplemented, "Not supported yet"
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
          raise NotImplemented, "Not supported yet"
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
          result = Utils.build_box(record, options).decrypt(result)
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

    module Model
      def attached_encrypted(name, **options)
        class_eval do
          @encrypted_attachments ||= {}

          unless respond_to?(:encrypted_attachments)
            def self.encrypted_attachments
              parent_attachments =
                if superclass.respond_to?(:encrypted_attachments)
                  superclass.encrypted_attachments
                else
                  {}
                end

              parent_attachments.merge(@encrypted_attachments || {})
            end
          end

          raise ArgumentError, "Duplicate encrypted attachment: #{name}" if encrypted_attachments[name]

          @encrypted_attachments[name] = options
        end
      end
    end
  end
end
