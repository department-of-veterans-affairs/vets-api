class AddFlaggedValueUpdatedAtColumn < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :flagged_veteran_representative_contact_data, :flagged_value_updated_at, :datetime, null: true

    # Remove the existing unique index
    remove_index :flagged_veteran_representative_contact_data, name: :index_unique_flagged_veteran_representative
    
    # Add a new unique index that includes the flagged_value_updated_at column
    add_index :flagged_veteran_representative_contact_data, [:ip_address, :representative_id, :flag_type, :flagged_value_updated_at], unique: true, name: :index_flagged_veteran_representative_with_updated_at, algorithm: :concurrently
  end
end
