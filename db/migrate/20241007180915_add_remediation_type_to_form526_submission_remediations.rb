class AddRemediationTypeToForm526SubmissionRemediations < ActiveRecord::Migration[7.1]
  def change
    add_column :form526_submission_remediationss, :remediation_type, :integer
  end
end
