class AddCiphertextFieldsToFormSubmissionAttempts < ActiveRecord::Migration[7.1]
  def change
    add_column :form_submission_attempts, :error_message_ciphertext, :text
    add_column :form_submission_attempts, :response_ciphertext, :jsonb
  end
end
