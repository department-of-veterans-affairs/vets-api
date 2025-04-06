class CreateLighthouseSubmissions < ActiveRecord::Migration[7.2]
  def change
    create_enum :lighthouse_submission_status, %w[pending submitted]

    create_table :lighthouse_submissions do |t|
      t.timestamps
      t.integer :saved_claim_id, null: false, comment: 'ID of the saved claim in vets-api'
      t.enum :latest_status, enum_type: 'lighthouse_submission_status', default: 'pending'
      t.string :form_id, null: false, comment: 'form type of the submission'
      t.jsonb :reference_data_ciphertext, comment: 'encrypted data that can be used to identify the resource - ie, ICN, etc'
    end
  end
end
