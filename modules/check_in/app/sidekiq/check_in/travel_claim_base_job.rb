# frozen_string_literal: true

require 'sidekiq'

module CheckIn
  class TravelClaimBaseJob
    include Sidekiq::Job
    include SentryLogging

    MAX_RETRIES = 12
    sidekiq_options retry: MAX_RETRIES

    OH_RESPONSES = Hash.new([Constants::OH_STATSD_BTSSS_ERROR, Constants::OH_ERROR_TEMPLATE_ID]).merge(
      TravelClaim::Response::CODE_SUCCESS => [Constants::OH_STATSD_BTSSS_SUCCESS, Constants::OH_SUCCESS_TEMPLATE_ID],
      TravelClaim::Response::CODE_CLAIM_EXISTS => [Constants::OH_STATSD_BTSSS_DUPLICATE,
                                                   Constants::OH_DUPLICATE_TEMPLATE_ID],
      TravelClaim::Response::CODE_BTSSS_TIMEOUT => [Constants::OH_STATSD_BTSSS_TIMEOUT,
                                                    Constants::OH_TIMEOUT_TEMPLATE_ID],
      TravelClaim::Response::CODE_EMPTY_STATUS => [Constants::OH_STATSD_BTSSS_ERROR, Constants::OH_ERROR_TEMPLATE_ID],
      TravelClaim::Response::CODE_MULTIPLE_STATUSES => [Constants::OH_STATSD_BTSSS_ERROR,
                                                        Constants::OH_ERROR_TEMPLATE_ID],
      TravelClaim::Response::CODE_CLAIM_APPROVED => [Constants::OH_STATSD_BTSSS_SUCCESS,
                                                     Constants::OH_SUCCESS_TEMPLATE_ID],
      TravelClaim::Response::CODE_CLAIM_NOT_APPROVED => [Constants::OH_STATSD_BTSSS_CLAIM_FAILURE,
                                                         Constants::OH_FAILURE_TEMPLATE_ID]
    )
    CIE_RESPONSES = Hash.new([Constants::CIE_STATSD_BTSSS_ERROR, Constants::CIE_ERROR_TEMPLATE_ID]).merge(
      TravelClaim::Response::CODE_SUCCESS => [Constants::CIE_STATSD_BTSSS_SUCCESS,
                                              Constants::CIE_SUCCESS_TEMPLATE_ID],
      TravelClaim::Response::CODE_CLAIM_EXISTS => [Constants::CIE_STATSD_BTSSS_DUPLICATE,
                                                   Constants::CIE_DUPLICATE_TEMPLATE_ID],
      TravelClaim::Response::CODE_BTSSS_TIMEOUT => [Constants::CIE_STATSD_BTSSS_TIMEOUT,
                                                    Constants::CIE_TIMEOUT_TEMPLATE_ID],
      TravelClaim::Response::CODE_EMPTY_STATUS => [Constants::CIE_STATSD_BTSSS_ERROR,
                                                   Constants::CIE_ERROR_TEMPLATE_ID],
      TravelClaim::Response::CODE_MULTIPLE_STATUSES => [Constants::CIE_STATSD_BTSSS_ERROR,
                                                        Constants::CIE_ERROR_TEMPLATE_ID],
      TravelClaim::Response::CODE_CLAIM_APPROVED => [Constants::CIE_STATSD_BTSSS_SUCCESS,
                                                     Constants::CIE_SUCCESS_TEMPLATE_ID],
      TravelClaim::Response::CODE_CLAIM_NOT_APPROVED => [Constants::CIE_STATSD_BTSSS_CLAIM_FAILURE,
                                                         Constants::CIE_FAILURE_TEMPLATE_ID]
    )

    FAILED_CLAIM_TEMPLATE_IDS = [Constants::CIE_TIMEOUT_TEMPLATE_ID, Constants::CIE_FAILURE_TEMPLATE_ID,
                                 Constants::CIE_ERROR_TEMPLATE_ID, Constants::OH_ERROR_TEMPLATE_ID,
                                 Constants::OH_FAILURE_TEMPLATE_ID, Constants::OH_TIMEOUT_TEMPLATE_ID].freeze


    def send_notification(opts = {})
      log_sending_travel_claim_notification(opts)
      retry_attempt = 0
      retry_attempt = self.class.sidekiq_options_hash['retry_count'].to_i if self.class.sidekiq_options_hash['retry_count']
      attempt_number = retry_attempt + 1

      begin
        va_notify_send_sms(opts)
      rescue => e
        log_send_sms_failure(attempt_number)

        raise e
      end
    end

    sidekiq_retries_exhausted do |job, ex|
      CheckIn::TravelClaimBaseJob.handle_error(job, ex)
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
      logger.info({ message: "Sending SMS failed, attempt #{attempt_number} of #{MAX_RETRIES}" })
    end
  end
end
