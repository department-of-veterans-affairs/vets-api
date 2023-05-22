# frozen_string_literal: true

require 'sidekiq'

module CheckIn
  class TravelClaimSubmissionWorker
    include Sidekiq::Worker
    include SentryLogging

    sidekiq_options retry: false

    SUCCESS_TEMPLATE_ID = Settings.vanotify.services.check_in.template_id.claim_submission_success_text
    DUPLICATE_TEMPLATE_ID = Settings.vanotify.services.check_in.template_id.claim_submission_duplicate_text
    ERROR_TEMPLATE_ID = Settings.vanotify.services.check_in.template_id.claim_submission_error_text

    SMS_SENDER_ID = Settings.vanotify.services.check_in.sms_sender_id

    STATSD_ERROR_NAME = 'worker.checkin.travel_claim.error'
    STATSD_SUCCESS_NAME = 'worker.checkin.travel_claim.success'

    def perform(uuid, appointment_date)
      check_in_session = CheckIn::V2::Session.build(data: { uuid: })
      mobile_phone = TravelClaim::RedisClient.build.mobile_phone(uuid:)

      logger.info("Submitting travel claim for #{uuid}, #{appointment_date}")

      claims_resp = TravelClaim::Service.build(
        check_in: check_in_session,
        params: { appointment_date: }
      ).submit_claim

      claim_number = claims_resp.dig(:data, :claimNumber)
      template_id = case claims_resp.dig(:data, :code)
                    when TravelClaim::Response::CODE_SUCCESS
                      SUCCESS_TEMPLATE_ID
                    when TravelClaim::Response::CODE_CLAIM_EXISTS
                      DUPLICATE_TEMPLATE_ID
                    else
                      ERROR_TEMPLATE_ID
                    end
      send_notification(mobile_phone:, appointment_date:, template_id:, claim_number:)
      StatsD.increment(STATSD_SUCCESS_NAME)
    end

    def send_notification(opts = {})
      notify_client = VaNotify::Service.new(Settings.vanotify.services.check_in.api_key)

      logger.info("Sending notification to (phone last four): #{opts[:mobile_phone].delete('^0-9').last(4)}," \
                  " using template_id: #{opts[:template_id]}")
      appt_date_in_mmm_dd_format = DateTime.strptime(opts[:appointment_date], '%Y-%m-%d').to_date.strftime('%b %d')

      notify_client.send_sms(
        phone_number: opts[:mobile_phone],
        template_id: opts[:template_id],
        sms_sender_id: SMS_SENDER_ID,
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
      StatsD.increment(STATSD_ERROR_NAME)
    end
  end
end
