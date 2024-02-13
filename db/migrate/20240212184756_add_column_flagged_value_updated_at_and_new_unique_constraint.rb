class AddColumnFlaggedValueUpdatedAtAndNewUniqueConstraint < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :flagged_veteran_representative_contact_data, :flagged_value_updated_at, :datetime, null: true
    add_index :flagged_veteran_representative_contact_data, [:ip_address, :representative_id, :flag_type, :flagged_value_updated_at], unique: true, name: :index_unique_constraint_fields, algorithm: :concurrently
  end
end
