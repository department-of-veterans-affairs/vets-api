# frozen_string_literal: true

module CheckIn
  class TravelClaimSubmissionJob < TravelClaimBaseJob
    def perform(uuid, appointment_date)
      redis_client = TravelClaim::RedisClient.build
      mobile_phone = redis_client.patient_cell_phone(uuid:) || redis_client.mobile_phone(uuid:)
      station_number = redis_client.station_number(uuid:)
      facility_type = redis_client.facility_type(uuid:)

      log_claim_submission(uuid, appointment_date, station_number, facility_type)
      claim_number, template_id = submit_claim(uuid:, appointment_date:, station_number:, facility_type:)

      if template_id && mobile_phone && appointment_date
        opts = { mobile_phone:, appointment_date:, template_id:, claim_number:, facility_type: }
        TravelClaimNotificationJob.perform_async(opts)
      else
        context = { uuid:, appointment_date:, station_number:, facility_type:, template_id:, mobile_phone: }
        log_missing_data(context)
      end
    end

    private

    def log_claim_submission(uuid, appointment_date, station_number, facility_type)
      logger.info({
                    message: "Submitting travel claim: #{uuid}",
                    uuid:,
                    appointment_date:,
                    station_number:,
                    facility_type:
                  })
    end

    def log_missing_data(context)
      missing = []
      missing << 'template_id' unless context[:template_id]
      missing << 'mobile_phone' unless context[:mobile_phone]
      missing << 'appointment_date' unless context[:appointment_date]

      logger.error({
                     message: "Missing data for notification: #{missing.join(', ')} for #{context[:uuid]}",
                     uuid: context[:uuid],
                     appointment_date: context[:appointment_date],
                     station_number: context[:station_number],
                     facility_type: context[:facility_type],
                     missing_data: missing
                   })
    end

    def submit_claim(opts = {})
      uuid, appointment_date, facility_type = opts.values_at(:uuid, :appointment_date, :facility_type)
      check_in_session = CheckIn::V2::Session.build(data: { uuid: })

      claims_resp = TravelClaim::Service.build(check_in: check_in_session,
                                               params: { appointment_date:, facility_type: })
                                        .submit_claim

      if should_handle_timeout(claims_resp)
        TravelClaimStatusCheckJob.perform_in(5.minutes, uuid, appointment_date)
      else
        handle_response(claims_resp:, facility_type:)
      end
    rescue => e
      logger.error({ message: "Error calling BTSSS Service: #{e.message}" }.merge(opts))
      if 'oh'.casecmp?(facility_type)
        StatsD.increment(Constants::OH_STATSD_BTSSS_ERROR)
        template_id = Constants::OH_ERROR_TEMPLATE_ID
      else
        StatsD.increment(Constants::CIE_STATSD_BTSSS_ERROR)
        template_id = Constants::CIE_ERROR_TEMPLATE_ID
      end
      [nil, template_id]
    end

    def handle_response(opts = {})
      claim_number = opts[:claims_resp]&.dig(:data, :claimNumber)&.last(4)
      code = opts[:claims_resp]&.dig(:data, :code)
      facility_type = opts[:facility_type] || ''

      statsd_metric, template_id = facility_type.downcase == 'oh' ? OH_RESPONSES[code] : CIE_RESPONSES[code]

      StatsD.increment(statsd_metric)
      [claim_number, template_id]
    end

    def should_handle_timeout(claims_resp)
      Flipper.enabled?(:check_in_experience_check_claim_status_on_timeout) &&
        claims_resp&.dig(:data, :code) == TravelClaim::Response::CODE_BTSSS_TIMEOUT
    end
  end
end
