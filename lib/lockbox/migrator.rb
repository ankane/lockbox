module Lockbox
  class Migrator
    def initialize(model)
      @model = model
    end

    def migrate(restart:)
      model = @model

      base_relation =
        if defined?(ActiveRecord::Base) && model.is_a?(ActiveRecord::Base)
          model.unscoped
        else
          # TODO don't unscope relations
          # waiting for 0.4.0
          # model.all
          model.unscoped
        end

      # get fields
      fields = model.lockbox_attributes.select { |k, v| v[:migrating] }

      # get blind indexes
      blind_indexes = model.respond_to?(:blind_indexes) ? model.blind_indexes.select { |k, v| v[:migrating] } : {}

      # build relation
      relation = base_relation

      unless restart
        attributes = fields.map { |_, v| v[:encrypted_attribute] }
        attributes += blind_indexes.map { |_, v| v[:bidx_attribute] }

        if defined?(ActiveRecord::Relation) && base_relation.is_a?(ActiveRecord::Relation)
          attributes.each_with_index do |attribute, i|
            relation =
              if i == 0
                relation.where(attribute => nil)
              else
                relation.or(base_relation.where(attribute => nil))
              end
          end
        end
      end

      if relation.respond_to?(:find_each)
        relation.find_each do |record|
          migrate_record(record, fields: fields, blind_indexes: blind_indexes, restart: restart)
        end
      else
        relation.all.each do |record|
          migrate_record(record, fields: fields, blind_indexes: blind_indexes, restart: restart)
        end
      end
    end

    private

    def migrate_record(record, fields:, blind_indexes:, restart:)
      fields.each do |k, v|
        record.send("#{v[:attribute]}=", record.send(k)) if restart || !record.send(v[:encrypted_attribute])
      end
      blind_indexes.each do |k, v|
        record.send("compute_#{k}_bidx") if restart || !record.send(v[:bidx_attribute])
      end
      record.save(validate: false) if record.changed?
    end
  end
end
