class AddBackupSubmittedClaimIdToForm526submissions < ActiveRecord::Migration[6.1]
  def change
    add_column(
      :form526_submissions,
      :backup_submitted_claim_id,
      :string,
      comment: '*After* a SubmitForm526 Job has exhausted all attempts, a paper submission is generated and sent to Central Mail Portal.'\
      'This column will be nil for all submissions where a backup submission is not generated.'\
      'It will have the central mail id for submissions where a backup submission is submitted.'
    )
  end
end
