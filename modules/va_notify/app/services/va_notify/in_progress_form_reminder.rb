# frozen_string_literal: true

module VANotify
  class InProgressFormReminder
    class MissingICN < StandardError; end
    class UnsupportedForm < StandardError; end

    def call(form_ids)
      return unless enabled?

      form_ids = Array(form_ids)
      # currently only supports notifying about one in progress form
      in_progress_form = InProgressForm.where(id: form_ids).first
      veteran = veteran_data(in_progress_form)

      raise MissingICN, "ICN not found for InProgressForm: #{in_progress_form.id}" if veteran.mpi_icn.blank?

      template_id = Settings.vanotify.services.va_gov.template_id.in_progress_reminder_email_generic
      IcnJob.perform_async(veteran.mpi_icn, template_id,
                           personalisation_details(in_progress_form, veteran.first_name.upcase))
    end

    private

    attr_accessor :form_ids

    def enabled?
      Flipper.enabled?(:in_progress_form_reminder)
    end

    def personalisation_details(in_progress_form, first_name)
      {
        'first_name' => first_name,
        'date' => in_progress_form.expires_at.strftime('%B %d, %Y')
      }
    end

    def veteran_data(in_progress_form)
      data = case in_progress_form.form_id
             when '686C-674'
               InProgressForm686c.new(in_progress_form.form_data)
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
