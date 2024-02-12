class AddIndexUniqueFlaggedVeteranRepresentativeBack < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :flagged_veteran_representative_contact_data, 
              ["ip_address", "representative_id", "flag_type"], 
              unique: true, 
              name: 'index_unique_flagged_veteran_representative',
              algorithm: :concurrently

  end
end
