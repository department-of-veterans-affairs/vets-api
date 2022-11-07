# frozen_string_literal: true

module VANotify
  class InProgressFormHelper
    TEMPLATE_ID = {
      '686C-674' => Settings.vanotify.services.va_gov.template_id.form686c_reminder_email,
      '1010ez' => Settings.vanotify.services.va_gov.template_id.form1010ez_reminder_email
    }.freeze

    FRIENDLY_FORM_SUMMARY = {
      '686C-674' => 'Application Request to Add or Remove Dependents',
      '1010ez' => 'Application for Health Benefits'
    }.freeze

    def self.form_age(in_progress_form)
      case in_progress_form.updated_at
      when 7.days.ago.beginning_of_day..7.days.ago.end_of_day
        '&7_days'
      else
        ''
      end
    end
  end
end
