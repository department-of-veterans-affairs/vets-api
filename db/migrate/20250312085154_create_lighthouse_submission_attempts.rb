class CreateLighthouseSubmissionAttempts < ActiveRecord::Migration[7.2]
  def change
    create_table :lighthouse_submission_attempts do |t|
      t.timestamps
      t.references :lighthouse_submission, null: false, foreign_key: true
      t.enum :status, enum_type: 'lighthouse_submission_status', default: 'pending'
      t.jsonb :metadata_ciphertext, comment: 'metadata sent with the submission'
      t.jsonb :error_message_ciphertext
      t.jsonb :response_ciphertext
      t.datetime :lighthouse_updated_at
      t.string :benefits_intake_uuid
    end
  end
end
