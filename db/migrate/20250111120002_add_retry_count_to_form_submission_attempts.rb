class AddRetryCountToFormSubmissionAttempts < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column :form_submission_attempts, :retry_count, :integer, default: 0, null: false
    add_index :form_submission_attempts, :retry_count, algorithm: :concurrently
  end
end
