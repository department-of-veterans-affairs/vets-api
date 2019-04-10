class CreateForm526Submissions < ActiveRecord::Migration[4.2]
  def change
    create_table :form526_submissions do |t|
      t.uuid :user_uuid, null: false
      t.integer :saved_claim_id, null: false, unique: true
      t.integer :submitted_claim_id, unique: true
      t.string :encrypted_auth_headers_json, null: false
      t.string :encrypted_auth_headers_json_iv, null: false
      t.string :encrypted_form_json, null: false
      t.string :encrypted_form_json_iv, null: false
      t.boolean :workflow_complete, null: false, default: false

      t.timestamps null:false
    end
  end
end
