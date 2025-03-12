class CreateBpdsSubmissionAttempts < ActiveRecord::Migration[7.2]
  def change
    create_table :bpds_submission_attempts do |t|
      t.timestamps
      t.references :bpds_submission, null: false, foreign_key: true
      t.enum :status, enum_type: 'bpds_submission_status', default: 'pending'
      t.jsonb :metadata_ciphertext
      t.jsonb :payload_ciphertext
      t.jsonb :error_message_ciphertext
      t.jsonb :response_ciphertext
      t.datetime :bpds_updated_at
      t.string :bpds_id
    end
  end
end
