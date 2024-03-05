class CreateFlaggedVeteranRepresentativeContactData < ActiveRecord::Migration[7.0]
  def change
    create_table :flagged_veteran_representative_contact_data do |t|
      t.string "ip_address", null: false
      t.string "representative_id", null: false
      t.string "flag_type", null: false
      t.text "flagged_value", null: false
      t.boolean "flagged_value_updated", default: false
      t.timestamps
    end

    add_index :flagged_veteran_representative_contact_data, 
              ["ip_address", "representative_id", "flag_type"], 
              unique: true, 
              name: 'index_unique_flagged_veteran_representative'
  end
end
