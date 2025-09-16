# frozen_string_literal: true

# create submission attempts table
class CreateClaimEvidenceApiSubmissionAttempts < ActiveRecord::Migration[7.2]

  # create the table
  def change
    create_table :claims_evidence_api_submission_attempts do |t|
      t.references :claims_evidence_api_submissions, null: false, foreign_key: true
      t.enum :status, enum_type: 'claims_evidence_api_submission_status', default: 'pending'
      t.jsonb :metadata_ciphertext, comment: 'encrypted metadata sent with the submission'
      t.jsonb :error_message_ciphertext, comment: 'encrypted error message from the claims evidence api submission'
      t.jsonb :response_ciphertext, comment: 'encrypted response from the claims evidence api submission'
      t.text :encrypted_kms_key, comment: 'KMS key used to encrypt the reference data'
      t.boolean :needs_kms_rotation, default: false, null: false

      t.timestamps
    end
  end
end
