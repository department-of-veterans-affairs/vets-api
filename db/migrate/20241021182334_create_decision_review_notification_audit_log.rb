class CreateDecisionReviewNotificationAuditLog < ActiveRecord::Migration[7.1]
  def change
    create_table :decision_review_notification_audit_logs do |t|
      t.text :notification_id
      t.text :status
      t.text :reference
      t.text :payload_ciphertext
      t.text :encrypted_kms_key

      t.timestamps
    end
    add_index :decision_review_notification_audit_logs, :notification_id
    add_index :decision_review_notification_audit_logs, :reference
  end
end
