# This migration comes from vye (originally 20240229184515)
class CreateVyeUserProfiles < ActiveRecord::Migration[7.0]
  def change
    create_table :vye_user_profiles do |t|
      t.binary :ssn_digest, limit: 16.bytes
      t.binary :file_number_digest, limit: 16.bytes
      t.string :icn

      t.timestamps
    end

    add_index :vye_user_profiles, :ssn_digest, unique: true
    add_index :vye_user_profiles, :file_number_digest, unique: true
    add_index :vye_user_profiles, :icn, unique: true
  end
end
