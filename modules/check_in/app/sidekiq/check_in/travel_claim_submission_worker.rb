# frozen_string_literal: true

module CheckIn
  class TravelClaimSubmissionWorker < TravelClaimBaseWorker
    def perform(uuid, appointment_date)
      redis_client = TravelClaim::RedisClient.build
      mobile_phone = redis_client.patient_cell_phone(uuid:)
      station_number = redis_client.station_number(uuid:)
      facility_type = redis_client.facility_type(uuid:)

      logger.info({
                    message: "Submitting travel claim for #{uuid}, #{appointment_date}, " \
                             "#{station_number}, #{facility_type}",
                    uuid:,
                    appointment_date:,
                    station_number:,
                    facility_type:
                  })

      claim_number, template_id = submit_claim(uuid:, appointment_date:, station_number:, facility_type:)

      unless template_id.nil?
        send_notification(mobile_phone:, appointment_date:, template_id:, claim_number:, facility_type:)
        StatsD.increment(Constants::STATSD_NOTIFY_SUCCESS)
      end
    end

    def submit_claim(opts = {})
      uuid, appointment_date, facility_type = opts.values_at(:uuid, :appointment_date, :facility_type)
      check_in_session = CheckIn::V2::Session.build(data: { uuid: })

      claims_resp = TravelClaim::Service.build(check_in: check_in_session, params: { appointment_date: }).submit_claim

      if should_handle_timeout(claims_resp)
        TravelClaimStatusCheckWorker.perform_in(5.minutes, uuid, appointment_date)
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

      statsd_metric, template_id = get_metric_and_template_id(code, facility_type)

      StatsD.increment(statsd_metric)
      [claim_number, template_id]
    end

    def get_metric_and_template_id(code, facility_type)
      oh_responses = Hash.new([Constants::OH_STATSD_BTSSS_ERROR, Constants::OH_ERROR_TEMPLATE_ID]).merge(
        TravelClaim::Response::CODE_SUCCESS => [Constants::OH_STATSD_BTSSS_SUCCESS, Constants::OH_SUCCESS_TEMPLATE_ID],
        TravelClaim::Response::CODE_CLAIM_EXISTS => [Constants::OH_STATSD_BTSSS_DUPLICATE,
                                                     Constants::OH_DUPLICATE_TEMPLATE_ID],
        TravelClaim::Response::CODE_BTSSS_TIMEOUT => [Constants::OH_STATSD_BTSSS_TIMEOUT,
                                                      Constants::OH_TIMEOUT_TEMPLATE_ID]
      )
      cie_responses = Hash.new([Constants::CIE_STATSD_BTSSS_ERROR, Constants::CIE_ERROR_TEMPLATE_ID]).merge(
        TravelClaim::Response::CODE_SUCCESS => [Constants::CIE_STATSD_BTSSS_SUCCESS,
                                                Constants::CIE_SUCCESS_TEMPLATE_ID],
        TravelClaim::Response::CODE_CLAIM_EXISTS => [Constants::CIE_STATSD_BTSSS_DUPLICATE,
                                                     Constants::CIE_DUPLICATE_TEMPLATE_ID],
        TravelClaim::Response::CODE_BTSSS_TIMEOUT => [Constants::CIE_STATSD_BTSSS_TIMEOUT,
                                                      Constants::CIE_TIMEOUT_TEMPLATE_ID]
      )

      facility_type.downcase == 'oh' ? oh_responses[code] : cie_responses[code]
    end

    def should_handle_timeout(claims_resp)
      Flipper.enabled?(:check_in_experience_check_claim_status_on_timeout) &&
        claims_resp&.dig(:data, :code) == TravelClaim::Response::CODE_BTSSS_TIMEOUT
    end
  end
end
