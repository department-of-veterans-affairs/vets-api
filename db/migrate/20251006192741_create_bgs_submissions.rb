class CreateBGSSubmissions < ActiveRecord::Migration[7.2]
  def change
    create_enum :bgs_submission_status, %w[pending submitted failure]

    create_table :bgs_submissions do |t|
      t.references :saved_claim, null: true, foreign_key: true
      t.string :form_id, null: false, comment: 'form type of the submission'
      t.enum :latest_status, enum_type: 'bgs_submission_status', default: 'pending'
      t.string :bgs_claim_id, comment: 'claim ID in BGS system'
      t.jsonb :reference_data_ciphertext, comment: 'encrypted data that can be used to identify the resource - ie, ICN, etc'
      t.text :encrypted_kms_key, comment: 'KMS key used to encrypt sensitive data'
      t.boolean :needs_kms_rotation, default: false, null: false

      t.timestamps
    end
  end
end