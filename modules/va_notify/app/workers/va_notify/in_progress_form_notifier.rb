# frozen_string_literal: true

require 'sidekiq'

module VANotify
  class InProgressFormNotifier
    class MissingICN < StandardError; end
    class UnsupportedForm < StandardError; end
    include Sidekiq::Worker
    include SentryLogging

    sidekiq_options retry: 13 # ~ approx 1 day

    STATSD_ERROR_NAME = 'worker.in_progress_form_email.error'
    STATSD_SUCCESS_NAME = 'worker.in_progress_form_email.success'

    def perform(in_progress_form_ids)
      return unless enabled?

      in_progress_forms = InProgressForm.where(id: in_progress_form_ids)
      notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
      template_id = 'template_id'
      veteran = veteran_data(in_progress_forms.first)

      raise MissingICN, "ICN not found for InProgressForm: #{in_progress_forms.first.id}" if veteran.mpi_icn.blank?

      notify_client.send_email(
        recipient_identifier: {
          id_value: veteran.mpi_icn,
          id_type: 'ICN'
        },
        template_id: template_id,
        personalisation: personalisation_details(in_progress_forms, veteran.first_name.capitalize)
      )
      StatsD.increment(STATSD_SUCCESS_NAME)
    rescue => e
      handle_errors(e)
    end

    private

    def enabled?
      Flipper.enabled?(:in_progress_form_reminder)
    end

    def handle_errors(ex)
      log_exception_to_sentry(ex)
      StatsD.increment(STATSD_ERROR_NAME)

      # allow sidekiq to handle retries
      raise
    end

    def personalisation_details(in_progress_forms, first_name)
      personalisation = in_progress_forms.flat_map.with_index do |form, i|
        [
          ["form_#{i}_name", form.form_id.upcase],
          ["form_#{i}_expiration", form.expires_at.strftime('%B %d, %Y')]
        ]
      end.to_h
      personalisation['first_name'] = first_name
      personalisation
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
