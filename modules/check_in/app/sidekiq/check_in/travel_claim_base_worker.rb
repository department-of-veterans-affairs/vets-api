# frozen_string_literal: true

require 'sidekiq'

module CheckIn
  class TravelClaimBaseWorker
    include Sidekiq::Job
    include SentryLogging

    sidekiq_options retry: false
    def send_notification(opts = {})
      notify_client = VaNotify::Service.new(Settings.vanotify.services.check_in.api_key)
      phone_last_four = opts[:mobile_phone].delete('^0-9').last(4)

      logger.info({
                    message: "Sending travel claim notification to #{phone_last_four}, #{opts[:template_id]}",
                    phone_last_four:,
                    template_id: opts[:template_id]
                  })
      appt_date_in_mmm_dd_format = DateTime.strptime(opts[:appointment_date], '%Y-%m-%d').to_date.strftime('%b %d')

      notify_client.send_sms(
        phone_number: opts[:mobile_phone],
        template_id: opts[:template_id],
        sms_sender_id: 'oh'.casecmp?(opts[:facility_type]) ? Constants::OH_SMS_SENDER_ID : Constants::CIE_SMS_SENDER_ID,
        personalisation: {
          claim_number: opts[:claim_number],
          appt_date: appt_date_in_mmm_dd_format
        }
      )
    rescue => e
      handle_error(e, opts)
      raise e
    end

    def handle_error(ex, opts = {})
      log_exception_to_sentry(
        ex,
        { phone_number: opts[:mobile_phone].delete('^0-9').last(4), template_id: opts[:template_id],
          claim_number: opts[:claim_number] },
        { error: :check_in_va_notify_job, team: 'check-in' }
      )
      StatsD.increment(Constants::STATSD_NOTIFY_ERROR)
    end
  end
end
