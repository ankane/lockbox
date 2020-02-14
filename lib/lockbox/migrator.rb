module Lockbox
  class Migrator
    def initialize(model)
      @model = model
    end

    def rotate(attributes:, batch_size:)
      fields = {}
      attributes.each do |a|
        # use key instad of v[:attribute] to make it more intuitive when migrating: true
        field = @model.lockbox_attributes[a]
        raise ArgumentError, "Unknown attribute: #{a}" unless field
        fields[a] = field
      end

      perform(fields: fields, blind_indexes: [], restart: true, batch_size: batch_size)
    end

    def migrate(restart:, batch_size:)
      fields = @model.lockbox_attributes.select { |k, v| v[:migrating] }

      blind_indexes = @model.respond_to?(:blind_indexes) ? model.blind_indexes.select { |k, v| v[:migrating] } : {}

      perform(fields: fields, blind_indexes: blind_indexes, restart: restart, batch_size: batch_size)
    end

    private

    def perform(fields:, blind_indexes:, restart:, batch_size:)
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

      if relation.respond_to?(:find_in_batches)
        relation.find_in_batches(batch_size: batch_size) do |records|
          migrate_records(records, fields: fields, blind_indexes: blind_indexes, restart: restart)
        end
      else
        each_batch(relation, batch_size: batch_size) do |records|
          migrate_records(records, fields: fields, blind_indexes: blind_indexes, restart: restart)
        end
      end
    end

    def migrate_records(records, fields:, blind_indexes:, restart:)
      # do computation outside of transaction
      # especially expensive blind index computation
      records.each do |record|
        fields.each do |k, v|
          record.send("#{v[:attribute]}=", record.send(k)) if restart || !record.send(v[:encrypted_attribute])
        end
        blind_indexes.each do |k, v|
          record.send("compute_#{k}_bidx") if restart || !record.send(v[:bidx_attribute])
        end
      end

      records.select! { |r| r.changed? }

      with_transaction do
        records.map { |r| r.save(validate: false) }
      end
    end

    def with_transaction
      if @model.respond_to?(:transaction)
        @model.transaction do
          yield
        end
      else
        yield
      end
    end

    def each_batch(scope, batch_size:)
      # https://github.com/karmi/tire/blob/master/lib/tire/model/import.rb
      # use cursor for Mongoid
      items = []
      scope.all.each do |item|
        items << item
        if items.length == batch_size
          yield items
          items = []
        end
      end
      yield items if items.any?
    end
  end
end
