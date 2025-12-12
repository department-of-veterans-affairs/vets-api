# frozen_string_literal: true

class AddPdfUploadColumnsToDecisionReviewNotificationAuditLogs < ActiveRecord::Migration[7.1]
  def change
    add_column :decision_review_notification_audit_logs, :pdf_uploaded_at, :datetime
    add_column :decision_review_notification_audit_logs, :vbms_file_uuid, :string
    add_column :decision_review_notification_audit_logs, :pdf_upload_attempt_count, :integer
    add_column :decision_review_notification_audit_logs, :pdf_upload_error, :text
  end
end
