class AddFailureToBpdsSubmissionStatusEnum < ActiveRecord::Migration[7.2]
  def change
    add_enum_value :bpds_submission_status, 'failure'
  end
end
