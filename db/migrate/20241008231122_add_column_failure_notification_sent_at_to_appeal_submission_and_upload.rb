class AddColumnFailureNotificationSentAtToAppealSubmissionAndUpload < ActiveRecord::Migration[7.1]
  def change
    # appeal_submissions
    add_column :appeal_submissions, :failure_notification_sent_at, :datetime
    
    # appeal_submission_uploads
    add_column :appeal_submission_uploads, :failure_notification_sent_at, :datetime
  end
end
