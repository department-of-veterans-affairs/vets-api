# frozen_string_literal: true

module VANotify
  class InProgressFormHelper
    TEMPLATE_ID = {
      'generic' => Settings.vanotify.services.va_gov.template_id.in_progress_reminder_email_generic,
      '686C-674' => Settings.vanotify.services.va_gov.template_id.form686c_reminder_email,
      '1010ez' => Settings.vanotify.services.va_gov.template_id.form1010ez_reminder_email,
      '21-526EZ' => Settings.vanotify.services.va_gov.template_id.form526ez_reminder_email
    }.freeze

    FRIENDLY_FORM_SUMMARY = {
      '686C-674' => 'Application Request to Add or Remove Dependents',
      '1010ez' => 'Application for Health Benefits',
      '21-526EZ' => 'Application for Disability Compensation and Related Compensation Benefits'
    }.freeze

    FRIENDLY_FORM_ID = {
      '686C-674' => '686C-674',
      '1010ez' => '10-10EZ',
      '21-526EZ' => '21-526EZ'
    }.freeze

    def self.form_age(in_progress_form)
      case in_progress_form.updated_at
      when 7.days.ago.all_day
        '&7_days'
      else
        ''
      end
    end
  end
end
