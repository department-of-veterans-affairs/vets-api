class ChangeClaimVANotificationEmailTemplateIdType < ActiveRecord::Migration[7.1]
  def up
    safety_assured do
      change_column :claim_va_notifications, :email_template_id, :string
    end
  end

  def down
    safety_assured do
      change_column :claim_va_notifications, :email_template_id, :integer
    end
  end
end
