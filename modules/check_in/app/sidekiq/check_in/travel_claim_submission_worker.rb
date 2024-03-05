# frozen_string_literal: true

require 'sidekiq'

module CheckIn
  class TravelClaimSubmissionWorker
    include Sidekiq::Job
    include SentryLogging

    sidekiq_options retry: false

    SUCCESS_TEMPLATE_ID = Settings.vanotify.services.check_in.template_id.claim_submission_success_text
    DUPLICATE_TEMPLATE_ID = Settings.vanotify.services.check_in.template_id.claim_submission_duplicate_text
    ERROR_TEMPLATE_ID = Settings.vanotify.services.check_in.template_id.claim_submission_error_text

    SMS_SENDER_ID = Settings.vanotify.services.check_in.sms_sender_id

    STATSD_NOTIFY_ERROR = 'worker.checkin.travel_claim.notify.error'
    STATSD_NOTIFY_SUCCESS = 'worker.checkin.travel_claim.notify.success'

    STATSD_BTSSS_SUCCESS = 'worker.checkin.travel_claim.btsss.success'
    STATSD_BTSSS_ERROR = 'worker.checkin.travel_claim.btsss.error'
    STATSD_BTSSS_DUPLICATE = 'worker.checkin.travel_claim.btsss.duplicate'

    def perform(uuid, appointment_date)
      redis_client = TravelClaim::RedisClient.build
      mobile_phone = redis_client.patient_cell_phone(uuid:)
      station_number = redis_client.station_number(uuid:)

      logger.info({
                    message: "Submitting travel claim for #{uuid}, #{appointment_date}, #{station_number}",
                    uuid:,
                    appointment_date:,
                    station_number:
                  })

      claim_number, template_id = submit_claim(uuid:, appointment_date:, station_number:)

      send_notification(mobile_phone:, appointment_date:, template_id:, claim_number:)
      StatsD.increment(STATSD_NOTIFY_SUCCESS)
    end

    def submit_claim(opts = {})
      check_in_session = CheckIn::V2::Session.build(data: { uuid: opts[:uuid] })
      claims_resp = TravelClaim::Service.build(
        check_in: check_in_session,
        params: { appointment_date: opts[:appointment_date] }
      ).submit_claim

      handle_response(claims_resp:)
    rescue Common::Exceptions::BackendServiceException => e
      logger.error({ message: "Error calling BTSSS Service: #{e.message}" }.merge(opts))
      StatsD.increment(STATSD_BTSSS_ERROR)
      [nil, ERROR_TEMPLATE_ID]
    end

    def handle_response(claims_resp:)
      claim_number = claims_resp&.dig(:data, :claimNumber)&.last(4)
      template_id =
        case claims_resp&.dig(:data, :code)
        when TravelClaim::Response::CODE_SUCCESS
          StatsD.increment(STATSD_BTSSS_SUCCESS)
          SUCCESS_TEMPLATE_ID
        when TravelClaim::Response::CODE_CLAIM_EXISTS
          StatsD.increment(STATSD_BTSSS_DUPLICATE)
          DUPLICATE_TEMPLATE_ID
        else
          StatsD.increment(STATSD_BTSSS_ERROR)
          ERROR_TEMPLATE_ID
        end
      [claim_number, template_id]
    end

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
      StatsD.increment(STATSD_NOTIFY_ERROR)
    end
  end
end
