module Lockbox
  module Calculations
    def pluck(*column_names)
      return super unless model.respond_to?(:lockbox_attributes)

      lockbox_columns = column_names.map.with_index { |c, i| [model.lockbox_attributes[c], i] }.select(&:first)
      return super unless lockbox_columns.any?

      # replace column with ciphertext column
      lockbox_columns.each do |la, i|
        column_names[i] = la[:encrypted_attribute]
      end

      # pluck
      result = super(*column_names)

      # decrypt result
      # handle pluck to single columns and multiple
      if column_names.size == 1
        la = lockbox_columns.first.first
        result.map! { |v| model.send("decrypt_#{la[:encrypted_attribute]}", v) }
      else
        lockbox_columns.each do |la, i|
          result.each do |v|
            v[i] = model.send("decrypt_#{la[:encrypted_attribute]}", v[i])
          end
        end
      end

      result
    end
  end
end
