# frozen_string_literal: true

module CheckIn
  class TravelClaimNotificationJob < TravelClaimBaseJob
    MAX_RETRIES = 12
    sidekiq_options retry: MAX_RETRIES

    def perform(opts = {})
      log_sending_travel_claim_notification(opts)
      retry_attempt = 0
      if self.class.sidekiq_options_hash&.[]('retry_count')
        retry_attempt = self.class.sidekiq_options_hash['retry_count'].to_i
      end
      attempt_number = retry_attempt + 1

      begin
        va_notify_send_sms(opts)
        StatsD.increment(Constants::STATSD_NOTIFY_SUCCESS)
      rescue => e
        log_send_sms_failure(attempt_number)
        StatsD.increment(Constants::STATSD_NOTIFY_ERROR)
        raise e
      end
    end

    sidekiq_retries_exhausted do |job, ex|
      CheckIn::TravelClaimNotificationJob.handle_error(job, ex)
    end

    def self.handle_error(job, ex)
      opts = job.dig('args', 0) || {}

      SentryLogging.log_exception_to_sentry(
        ex,
        {
          phone_number: phone_last_four(opts),
          template_id: safe_get(opts, :template_id),
          claim_number: safe_get(opts, :claim_number)
        },
        { error: :check_in_va_notify_job, team: 'check-in' }
      )

      if FAILED_CLAIM_TEMPLATE_IDS.include?(safe_get(opts, :template_id))
        tags = if safe_get(opts, :facility_type) == 'cie'
                 Constants::STATSD_CIE_SILENT_FAILURE_TAGS
               else
                 Constants::STATSD_OH_SILENT_FAILURE_TAGS
               end
        StatsD.increment(Constants::STATSD_NOTIFY_SILENT_FAILURE, tags:)
      end

      StatsD.increment(Constants::STATSD_NOTIFY_ERROR)
    end

    def self.safe_get(hash, key)
      hash&.[](key)
    end

    def self.phone_last_four(hash)
      safe_get(hash, :mobile_phone)&.delete('^0-9')&.last(4)
    end

    private

    def notify_client
      @notify_client ||= VaNotify::Service.new(Settings.vanotify.services.check_in.api_key)
    end

    def log_sending_travel_claim_notification(opts)
      phone_last_four = self.class.phone_last_four(opts)
      template_id = self.class.safe_get(opts, :template_id)

      log_message_and_context = {
        message: "Sending travel claim notification to #{phone_last_four}, #{template_id}",
        phone_last_four: phone_last_four,
        template_id: template_id
      }.compact

      logger.info(log_message_and_context)
    end

    def va_notify_send_sms(opts)
      appt_date = begin
        DateTime.strptime(self.class.safe_get(opts, :appointment_date).to_s,
                          '%Y-%m-%d').to_date.strftime('%b %d')
      rescue
        'Unknown Date'
      end

      sms_sender_id = if self.class.safe_get(opts,
                                             :facility_type) && 'oh'.casecmp?(self.class.safe_get(opts, :facility_type))
                        Constants::OH_SMS_SENDER_ID
                      else
                        Constants::CIE_SMS_SENDER_ID
                      end

      phone_number = self.class.safe_get(opts, :mobile_phone)
      template_id = self.class.safe_get(opts, :template_id)
      personalisation = { claim_number: self.class.safe_get(opts, :claim_number), appt_date: appt_date }

      notify_client.send_sms(phone_number:, template_id:, sms_sender_id:, personalisation:)
    end

    def log_send_sms_failure(attempt_number)
      logger.info({ message: "Sending SMS failed, attempt #{attempt_number} of #{MAX_RETRIES + 1}" })
    end
  end
end
