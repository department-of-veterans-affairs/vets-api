class CreateBGSSubmissionAttempts < ActiveRecord::Migration[7.2]
  def change
    create_table :bgs_submission_attempts do |t|
      t.references :bgs_submission, null: false, foreign_key: true
      t.enum :status, default: 'pending', enum_type: 'bgs_submission_status'
      t.jsonb :metadata_ciphertext, comment: 'encrypted metadata sent with the submission'
      t.jsonb :error_message_ciphertext, comment: 'encrypted error message from the bgs submission'
      t.jsonb :response_ciphertext, comment: 'encrypted response from the bgs submission'
      t.datetime :bgs_updated_at, comment: 'timestamp of the last update from bgs'
      t.string :bgs_claim_id, comment: 'claim ID returned from BGS'
      t.text :encrypted_kms_key, comment: 'KMS key used to encrypt sensitive data'
      t.boolean :needs_kms_rotation, default: false, null: false
      t.datetime :submitted_at, comment: 'timestamp when submitted to BGS'

      t.timestamps
    end
  end
end