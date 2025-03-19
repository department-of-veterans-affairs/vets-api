class CreateLighthouseSubmissions < ActiveRecord::Migration[7.2]
  def change
    create_enum :lighthouse_submission_status, %w[pending submitted]

    create_table :lighthouse_submissions do |t|
      t.timestamps
      t.integer :saved_claim_id, null: false
      t.enum :latest_status, enum_type: 'lighthouse_submission_status', default: 'pending'
      t.string :form_id, null: false
      t.jsonb :reference_data_ciphertext
    end
  end
end
