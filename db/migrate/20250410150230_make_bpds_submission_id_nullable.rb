class MakeBpdsSubmissionIdNullable < ActiveRecord::Migration[7.2]
  def change
    change_column_null :bpds_submission_attempts, :bpds_submission_id, true
  end
end
