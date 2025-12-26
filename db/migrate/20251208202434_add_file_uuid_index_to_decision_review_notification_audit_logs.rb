# frozen_string_literal: true

class AddFileUuidIndexToDecisionReviewNotificationAuditLogs < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :decision_review_notification_audit_logs, :vbms_file_uuid,
              algorithm: :concurrently,
              if_not_exists: true
  end
end
