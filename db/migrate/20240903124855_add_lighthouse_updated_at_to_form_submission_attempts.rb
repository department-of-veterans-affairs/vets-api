class AddLighthouseUpdatedAtToFormSubmissionAttempts < ActiveRecord::Migration[7.1]
  def change
    add_column :form_submission_attempts, :lighthouse_updated_at, :datetime
  end
end
