class CreateArpInProgressForms < ActiveRecord::Migration[7.2]
  def change
    create_table :arp_in_progress_forms do |t|
      t.string :user_uuid, null: false
      t.string :form_id, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.json :metadata
      t.datetime :expires_at
      t.text :form_data_ciphertext
      t.text :encrypted_kms_key
      t.uuid :user_account_id
      t.integer :status, default: 0

      t.index [:form_id, :user_uuid], unique: true, name: "index_arp_in_progress_forms_on_form_id_and_user_uuid"
      t.index :user_account_id, name: "index_arp_in_progress_forms_on_user_account_id"
      t.index :user_uuid, name: "index_arp_in_progress_forms_on_user_uuid"
    end
  end
end
