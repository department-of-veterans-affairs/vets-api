class CreateBPDSSubmissions < ActiveRecord::Migration[7.2]
  def change
    create_enum :bpds_submission_status, %w[pending submitted]

    create_table :bpds_submissions do |t|
      t.timestamps
      t.integer :saved_claim_id, null: false, comment: 'ID of the saved claim in vets-api'
      t.enum :latest_status, enum_type: 'bpds_submission_status', default: 'pending'
      t.string :form_id, null: false, comment: 'form type of the submission'
      t.string :va_claim_id, comment: 'claim ID in VA (non-vets-api) systems'
      t.jsonb :reference_data_ciphertext, comment: 'encrypted data that can be used to identify the resource - ie, ICN, etc'
    end
  end
end
