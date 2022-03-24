# frozen_string_literal: true

require 'sidekiq'

module VANotify
  class InProgressFormNotifier
    class MissingICN < StandardError; end
    include Sidekiq::Worker
    include SentryLogging

    sidekiq_options retry: 13 # ~ approx 1 day

    STATSD_ERROR_NAME = 'worker.in_progress_form_email.error'
    STATSD_SUCCESS_NAME = 'worker.in_progress_form_email.success'

    def perform(in_progress_form_ids)
      return unless enabled?

      in_progress_forms = InProgressForm.where(id: in_progress_form_ids)
      first_form = in_progress_forms.first

      notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
      template_id = 'template_id'
      veteran = User.find(string_to_uuid(first_form.user_uuid))

      raise MissingICN, "ICN not found for InProgressForm: #{first_form.id}" if veteran&.icn.blank?

      notify_client.send_email(
        recipient_identifier: {
          id_value: veteran.icn,
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

    def string_to_uuid(string)
      string.insert(8, '-').insert(13, '-').insert(18, '-').insert(23, '-')
    end
  end
end
