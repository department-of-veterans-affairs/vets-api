class AddNeedsKmsRotationToEncryptedModels < ActiveRecord::Migration[7.2]
  def change
    tables = ApplicationRecord.descendants_using_encryption.map(&:table_name).uniq

    tables.each do |table|
      add_column table, :needs_kms_rotation, :boolean, default: false, null: false
    end
  end
end
