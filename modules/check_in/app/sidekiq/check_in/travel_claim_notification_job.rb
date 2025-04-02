# frozen_string_literal: true

module CheckIn
  class TravelClaimNotificationJob < TravelClaimBaseJob
    MAX_RETRIES = 12
    sidekiq_options retry: MAX_RETRIES

    def perform(opts = {})
      log_sending_travel_claim_notification(opts)
      retry_attempt = 0

      if self.class.sidekiq_options_hash['retry_count']
        retry_attempt = self.class.sidekiq_options_hash['retry_count'].to_i
      end
      attempt_number = retry_attempt + 1

      begin
        va_notify_send_sms(opts)
      rescue => e
        log_send_sms_failure(attempt_number)

        raise e
      end
    end

    sidekiq_retries_exhausted do |job, ex|
      CheckIn::TravelClaimNotificationJob.handle_error(job, ex)
    end

    def self.handle_error(job, ex)
      opts = job['args'].first
      template_id = opts[:template_id]
      SentryLogging.log_exception_to_sentry(
        ex,
        { phone_number: opts[:mobile_phone].delete('^0-9').last(4), template_id:,
          claim_number: opts[:claim_number] },
        { error: :check_in_va_notify_job, team: 'check-in' }
      )

      if FAILED_CLAIM_TEMPLATE_IDS.include?(template_id)
        tags = if 'oh'.casecmp?(opts[:facility_type])
                 Constants::STATSD_OH_SILENT_FAILURE_TAGS
               else
                 Constants::STATSD_CIE_SILENT_FAILURE_TAGS
               end
        StatsD.increment(Constants::STATSD_NOTIFY_SILENT_FAILURE, tags:)
      end

      StatsD.increment(Constants::STATSD_NOTIFY_ERROR)
    end

    private

    def notify_client
      @notify_client ||= VaNotify::Service.new(Settings.vanotify.services.check_in.api_key)
    end

    def log_sending_travel_claim_notification(opts)
      phone_last_four = opts[:mobile_phone].delete('^0-9').last(4)
      log_message_and_context = {
        message: "Sending travel claim notification to #{phone_last_four}, #{opts[:template_id]}",
        phone_last_four:,
        template_id: opts[:template_id]
      }
      logger.info(log_message_and_context)
    end

    def va_notify_send_sms(opts)
      appt_date = DateTime.strptime(opts[:appointment_date], '%Y-%m-%d').to_date.strftime('%b %d')
      sms_sender_id = 'oh'.casecmp?(opts[:facility_type]) ? Constants::OH_SMS_SENDER_ID : Constants::CIE_SMS_SENDER_ID
      phone_number = opts[:mobile_phone]
      template_id = opts[:template_id]
      personalisation = { claim_number: opts[:claim_number], appt_date: }

      notify_client.send_sms(phone_number:, template_id:, sms_sender_id:, personalisation:)
    end

    def log_send_sms_failure(attempt_number)
      logger.info({ message: "Sending SMS failed, attempt #{attempt_number} of #{MAX_RETRIES + 1}" })
    end
  end
end
