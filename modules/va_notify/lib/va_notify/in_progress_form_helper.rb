# frozen_string_literal: true

module VANotify
  class InProgressFormHelper
    class UnsupportedForm < StandardError; end

    TEMPLATE_ID = {
      '686C-674' => Settings.vanotify.services.va_gov.template_id.form686c_reminder_email,
      '1010ez' => Settings.vanotify.services.va_gov.template_id.form1010ez_reminder_email
    }.freeze

    FRIENDLY_FORM_SUMMARY = {
      '686C-674' => 'Application Request to Add or Remove Dependents',
      '1010ez' => 'Application for Health Benefits'
    }.freeze

    def self.veteran_data(in_progress_form)
      data = case in_progress_form.form_id
             when '686C-674'
               InProgressForm686c.new(in_progress_form.form_data)
             when '1010ez'
               InProgressForm1010ez.new(in_progress_form.form_data)
             else
               raise UnsupportedForm,
                     "Unsupported form: #{in_progress_form.form_id} - InProgressForm: #{in_progress_form.id}"
             end

      VANotify::Veteran.new(
        ssn: data.ssn,
        first_name: data.first_name,
        last_name: data.last_name,
        birth_date: data.birth_date
      )
    end
  end
end
