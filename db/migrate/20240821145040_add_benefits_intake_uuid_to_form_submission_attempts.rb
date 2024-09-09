class AddBenefitsIntakeUuidToFormSubmissionAttempts < ActiveRecord::Migration[7.1]
  def change
    add_column :form_submission_attempts, :benefits_intake_uuid, :uuid
  end
end
