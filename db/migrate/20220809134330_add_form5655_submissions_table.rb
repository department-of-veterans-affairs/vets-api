class AddForm5655SubmissionsTable < ActiveRecord::Migration[6.1]
  def change
    create_table :form5655_submissions, id: :uuid do |t|
      t.string :user_uuid, null: false
      t.text   :form_json_ciphertext, null: false
      t.text   :metadata_ciphertext
      t.text   :encrypted_kms_key

      t.timestamps
    end
  end
end
