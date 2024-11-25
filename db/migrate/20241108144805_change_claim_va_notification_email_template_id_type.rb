class ChangeClaimVANotificationEmailTemplateIdType < ActiveRecord::Migration[7.1]
  def up
    safety_assured do
      rename_column :claim_va_notifications, :email_template_id, :email_template_id_int
      add_column :claim_va_notifications, :email_template_id, :string

      vanotify_service = Settings.vanotify.services
      pension_template_id = vanotify_service['pensions'].email.confirmation.template_id
      burial_template_id = vanotify_service['burials'].email.confirmation.template_id

      ClaimVANotification.all.each do |cvn|
        case cvn.form_type
        when '21P-527EZ'
          cvn.update!(email_template_id: pension_template_id)
        when '21P-530', '21P-530V2', '21P-530EZ'
          cvn.update!(email_template_id: burial_template_id)
        end
      end

      remove_column :claim_va_notifications, :email_template_id_int, if_exists: true
    end
  end

  def down
    safety_assured do
      change_column :claim_va_notifications, :email_template_id, :integer, using: 0
    end
  end
end
