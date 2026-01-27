# frozen_string_literal: true

class CreateFormIntakeSubmissions < ActiveRecord::Migration[7.0]
  def change
    create_table :form_intake_submissions do |t|
      t.references :form_submission, null: false, foreign_key: true, index: true

      # Status tracking
      t.string :aasm_state, null: false, default: 'pending'
      t.integer :retry_count, default: 0, null: false

      # Correlation UUID from Lighthouse Benefits Intake submission
      # This UUID links the GCIO submission to the original Lighthouse PDF upload
      t.string :benefits_intake_uuid, null: false

      # GCIO API response identifiers
      t.string :form_intake_submission_id
      t.string :gcio_tracking_number

      # Encrypted fields using Lockbox + KMS
      # These columns store encrypted data; actual field names used in code are without _ciphertext
      t.text :request_payload_ciphertext
      t.text :response_ciphertext
      t.text :error_message_ciphertext
      
      # KMS encryption key management
      t.text :encrypted_kms_key, comment: 'KMS key used to encrypt sensitive data'
      t.boolean :needs_kms_rotation, default: false, null: false

      # Timestamps for tracking submission lifecycle
      t.datetime :submitted_at
      t.datetime :completed_at
      t.datetime :last_attempted_at

      t.timestamps
    end
  end
end
