class AddNeedsKmsRotationFieldsToSubmissionsTables < ActiveRecord::Migration[7.2]
  def change
    tables = ApplicationRecord.descendants_using_encryption.select do |t|
      !t.column_names.include?('needs_kms_rotation')
    end.map(&:table_name).uniq

    tables.each do |table|
      add_column table, :needs_kms_rotation, :boolean, default: false, null: false
    end
  end
end
