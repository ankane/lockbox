module Lockbox
  module ShrinePlugin
    module ClassMethods
      def encrypt(**options)
        class_eval do
          class << self
            attr_accessor :lockbox_options
          end
          self.lockbox_options = options

          define_method :put do |io, context|
            record = context[:record]
            table = record ? record.class.table_name : "_uploader"
            attribute =
              if context[:name]
                context[:name].to_s
              else
                self.class.name.sub(/Uploader\z/, "").underscore
              end

            box = Utils.build_box(self, options, table, attribute)

            # io.rewind # maybe
            io = StringIO.new(box.encrypt(io.read))

            super(io, context)
          end
        end
      end
    end

    module FileMethods
      attr_accessor :context

      def io
        io = super
        if shrine_class.respond_to?(:lockbox_options)
          record = context[:record] if context

          table = record ? record.class.table_name : "_uploader"
          attribute =
            if context
              context[:name].to_s
            else
              shrine_class.name.sub(/Uploader\z/, "").underscore
            end

          options = shrine_class.lockbox_options
          box = Utils.build_box(uploader, options, table, attribute)
          io = StringIO.new(box.decrypt(io.read))
        end
        io
      end

      def rotate_encryption!
        p "rotate"
        p data
      end
    end

    module AttacherMethods
      def uploaded_file(value)
        file = super
        file.context = context
        file
      end
    end
  end
end

Shrine.plugin Lockbox::ShrinePlugin
