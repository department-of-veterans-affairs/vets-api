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

      # currently only supports notifying about one in progress form
      in_progress_form = InProgressForm.where(id: in_progress_form_ids).first
      notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
      template_id = Settings.vanotify.services.va_gov.template_id.form686c_reminder_email
      veteran = veteran_data(in_progress_form)

      raise MissingICN, "ICN not found for InProgressForm: #{in_progress_form.id}" if veteran.mpi_icn.blank?

      notify_client.send_email(
        recipient_identifier: {
          id_value: veteran.mpi_icn,
          id_type: 'ICN'
        },
        template_id: template_id,
        personalisation: personalisation_details(in_progress_form, veteran.first_name.upcase)
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
