class CreateFormSubmissionAttempts < ActiveRecord::Migration[6.1]
  def change
    create_table :form_submission_attempts do |t|
      t.references :form_submission, foreign_key: true, null: false
      t.jsonb :response
      t.string :aasm_state
      t.string :error_message
      t.text :encrypted_kms_key

      t.timestamps
    end
  end
end
