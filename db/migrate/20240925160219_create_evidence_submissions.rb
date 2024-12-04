class CreateEvidenceSubmissions < ActiveRecord::Migration[7.1]
  def change
    create_table :evidence_submissions do |t|
      t.string :job_id
      t.string :job_class
      t.string :request_id
      t.string :claim_id
      t.references :user_account, null: false, foreign_key: true, type: :uuid
      # TODO: store first name, filename, doctype, and anything we want to show on the frontend or in emails
      t.json :template_metadata_ciphertext
      t.text :encrypted_kms_key
      t.string :upload_status
      t.string :va_notify_id
      t.string :va_notify_status
      t.date :delete_date
      t.datetime :acknowledgement_date
      t.datetime :failed_date
      t.string :error_message
      t.string :tracked_item_id

      t.timestamps
    end
  end
end
