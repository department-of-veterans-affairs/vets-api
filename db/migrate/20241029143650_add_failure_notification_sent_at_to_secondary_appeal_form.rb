class AddFailureNotificationSentAtToSecondaryAppealForm < ActiveRecord::Migration[7.1]
  def change
    add_column :secondary_appeal_forms, :failure_notification_sent_at, :datetime
  end
end
