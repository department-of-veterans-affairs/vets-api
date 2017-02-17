class CreateFormProfiles < ActiveRecord::Migration
  def change
    create_table :form_profiles do |t|
      t.uuid :user_uuid, null: false
      t.string :encrypted_form_profile, null: false
      t.string :encrypted_form_profile_iv, null: false, :unique => true
      t.timestamps null: false
    end

    add_index(:form_profiles, :user_uuid)
  end
end
