# frozen_string_literal: true

class AddDefaultToPdfUploadAttemptCount < ActiveRecord::Migration[7.1]
  def up
    change_column_default :decision_review_notification_audit_logs, :pdf_upload_attempt_count, 0
  end
end
