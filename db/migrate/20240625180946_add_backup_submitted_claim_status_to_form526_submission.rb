class AddBackupSubmittedClaimStatusToForm526Submission < ActiveRecord::Migration[7.1]
  def change
    add_column :form526_submissions, :backup_submitted_claim_status, :integer
  end
end
