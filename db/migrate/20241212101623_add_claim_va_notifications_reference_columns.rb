class AddClaimVANotificationsReferenceColumns < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      add_column :claim_va_notifications, :notification_id, :uuid
      add_column :claim_va_notifications, :notification_type, :string
      add_column :claim_va_notifications, :notification_status, :string
    end
  end
end
