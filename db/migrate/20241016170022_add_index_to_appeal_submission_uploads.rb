class AddIndexToAppealSubmissionUploads < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :appeal_submission_uploads, :appeal_submission_id, algorithm: :concurrently
  end
end
