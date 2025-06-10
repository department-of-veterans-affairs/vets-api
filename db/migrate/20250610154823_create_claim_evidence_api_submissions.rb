class CreateClaimEvidenceAPISubmissions < ActiveRecord::Migration[7.2]
  def change
    create_enum :claims_evidence_api_submission_status, %w[pending accepted failed]

    create_table :claims_evidence_api_submissions do |t|
      t.integer :saved_claim_id, null: false, comment: 'ID of the saved claim in vets-api'
      t.enum :latest_status, enum_type: 'claims_evidence_api_submission_status', default: 'pending'
      t.string :form_id, null: false, comment: 'form type of the submission'
      t.string :va_claim_id, comment: 'claim ID in VA (non-vets-api) systems'
      t.jsonb :reference_data_ciphertext, comment: 'encrypted data that can be used to identify the resource'
      t.text :encrypted_kms_key, comment: 'KMS key used to encrypt the reference data'
      t.boolean :needs_kms_rotation, default: false, null: false

      t.timestamps
    end
  end
end
