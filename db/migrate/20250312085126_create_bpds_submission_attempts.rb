class CreateBpdsSubmissionAttempts < ActiveRecord::Migration[7.2]
  def change
    create_table :bpds_submission_attempts do |t|
      t.timestamps
      t.references :bpds_submission, null: false, foreign_key: true
      t.enum :status, enum_type: 'bpds_submission_status', default: 'pending'
      t.jsonb :metadata_ciphertext, comment: 'encrypted metadata sent with the submission'
      t.jsonb :error_message_ciphertext, comment: 'encrypted error message from the bpds submission'
      t.jsonb :response_ciphertext, comment: 'encrypted response from the bpds submission'
      t.datetime :bpds_updated_at, comment: 'timestamp of the last update from bpds'
      t.string :bpds_id, comment: 'ID of the submission in BPDS'
    end
  end
end
