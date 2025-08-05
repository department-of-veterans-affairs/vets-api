class AddNeedsKmsRotationIndicesToSubmissionTables < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    tables = ApplicationRecord.descendants_using_encryption.select do |t|
      !t.column_names.include?('needs_kms_rotation')
    end.map(&:table_name).uniq

    tables.each do |table|
      add_index table,
                :needs_kms_rotation,
                algorithm: :concurrently,
                if_not_exists: true
    end
  end
end
