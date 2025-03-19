class CreateBpdsSubmissions < ActiveRecord::Migration[7.2]
  def change
    create_enum :bpds_submission_status, %w[pending submitted]

    create_table :bpds_submissions do |t|
      t.timestamps
      t.integer :saved_claim_id, null: false
      t.enum :latest_status, enum_type: 'bpds_submission_status', default: 'pending'
      t.string :form_id, null: false
      t.string :va_claim_id
      t.jsonb :reference_data_ciphertext
    end
  end
end
