# frozen_string_literal: true

# create submissions table
class CreateClaimEvidenceApiSubmissions < ActiveRecord::Migration[7.2]

  # create the table
  def change
    create_table :claims_evidence_api_submissions do |t|
      t.string :form_id, null: false, comment: 'form type of the submission'
      t.enum :latest_status, enum_type: 'claims_evidence_api_submission_status', default: 'pending'
      t.string :va_claim_id, comment: 'uuid returned from claims evidence api'
      t.jsonb :reference_data_ciphertext, comment: 'encrypted data that can be used to identify the resource'
      t.text :encrypted_kms_key, comment: 'KMS key used to encrypt the reference data'
      t.boolean :needs_kms_rotation, default: false, null: false

      t.integer :saved_claim_id, null: false, comment: 'ID of the saved claim in vets-api'
      t.integer :persistent_attachment_id, comment: 'ID of the attachment in vets-api'

      t.timestamps
    end
  end
end
