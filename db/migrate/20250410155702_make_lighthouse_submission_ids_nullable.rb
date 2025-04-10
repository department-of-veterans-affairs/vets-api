class MakeLighthouseSubmissionIdsNullable < ActiveRecord::Migration[7.2]
  def change
    change_column_null :lighthouse_submissions, :saved_claim_id, true
    change_column_null :lighthouse_submission_attempts, :lighthouse_submission_id, true
  end
end
