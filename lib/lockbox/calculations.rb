module Lockbox
  module Calculations
    def pluck(*column_names)
      return super unless model.respond_to?(:lockbox_attributes)

      lockbox_columns = column_names.map.with_index do |c, i|
        next unless c.respond_to?(:to_sym)
        [model.lockbox_attributes[c.to_sym], i]
      end.select do |la, _i|
        la && !la[:migrating]
      end

      return super unless lockbox_columns.any?

      associated_columns_names = []
      # replace column with ciphertext column
      lockbox_columns.each do |la, i|
        column_names[i] = la[:encrypted_attribute]
        associated_columns_names.push(la[:with_associated_field]) if la[:with_associated_field]
      end

      # pluck
      all_columns = (column_names + associated_columns_names).map(&:to_s).compact.uniq
      result = super(*all_columns)
      result_hash = result.map do |fields|
        if all_columns.length == 1
          column_name = all_columns.first
          { column_name => fields }
        else
          all_columns.zip(fields).to_h
        end
      end

      # decrypt result
      # handle pluck to single columns and multiple
      #
      # we can't pass context to decrypt method
      # so this won't work if any options are a symbol or proc
      lockbox_columns.each do |la, i|
        encrypted_attr = la[:encrypted_attribute]
        associated_attr = la[:with_associated_field] || nil
        result_hash.each do |record|
          record[encrypted_attr] = model.send("decrypt_#{la[:encrypted_attribute]}", record[encrypted_attr], record[associated_attr].to_s || '')
        end
      end

      result = result_hash.map { |record| record.slice(*column_names.map(&:to_s)).values }
      result.flatten! if column_names.size == 1
      result
    end
  end
end
