class AddRemediationTypeToForm526SubmissionRemediations < ActiveRecord::Migration[7.1]
  def change
    add_column :form526_submission_remediations, :remediation_type, :integer, default: 0
  end
end
