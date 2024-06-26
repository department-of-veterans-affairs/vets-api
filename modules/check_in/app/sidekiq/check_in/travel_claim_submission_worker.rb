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

      send_notification(mobile_phone:, appointment_date:, template_id:, claim_number:, facility_type:)
      StatsD.increment(Constants::STATSD_NOTIFY_SUCCESS)
    end

    def submit_claim(opts = {})
      check_in_session = CheckIn::V2::Session.build(data: { uuid: opts[:uuid] })

      claims_resp = TravelClaim::Service.build(
        check_in: check_in_session,
        params: { appointment_date: opts[:appointment_date] }
      ).submit_claim

      handle_response(claims_resp:, facility_type: opts[:facility_type])
    rescue => e
      logger.error({ message: "Error calling BTSSS Service: #{e.message}" }.merge(opts))
      if 'oh'.casecmp?(opts[:facility_type])
        StatsD.increment(Constants::OH_STATSD_BTSSS_ERROR)
        template_id = Constants::OH_ERROR_TEMPLATE_ID
      else
        StatsD.increment(Constants::CIE_STATSD_BTSSS_ERROR)
        template_id = Constants::CIE_ERROR_TEMPLATE_ID
      end
      [nil, template_id]
    end

    # rubocop:disable Metrics/MethodLength
    def handle_response(opts = {})
      claim_number = opts[:claims_resp]&.dig(:data, :claimNumber)&.last(4)
      code = opts[:claims_resp]&.dig(:data, :code)
      facility_type = opts[:facility_type] || ''

      statsd_metric, template_id = case facility_type.downcase
                                   when 'oh'
                                     case code
                                     when TravelClaim::Response::CODE_SUCCESS
                                       [Constants::OH_STATSD_BTSSS_SUCCESS, Constants::OH_SUCCESS_TEMPLATE_ID]
                                     when TravelClaim::Response::CODE_CLAIM_EXISTS
                                       [Constants::OH_STATSD_BTSSS_DUPLICATE, Constants::OH_DUPLICATE_TEMPLATE_ID]
                                     when TravelClaim::Response::CODE_BTSSS_TIMEOUT
                                       [Constants::OH_STATSD_BTSSS_TIMEOUT, Constants::OH_TIMEOUT_TEMPLATE_ID]
                                     else
                                       [Constants::OH_STATSD_BTSSS_ERROR, Constants::OH_ERROR_TEMPLATE_ID]
                                     end
                                   else
                                     case code
                                     when TravelClaim::Response::CODE_SUCCESS
                                       [Constants::CIE_STATSD_BTSSS_SUCCESS, Constants::CIE_SUCCESS_TEMPLATE_ID]
                                     when TravelClaim::Response::CODE_CLAIM_EXISTS
                                       [Constants::CIE_STATSD_BTSSS_DUPLICATE, Constants::CIE_DUPLICATE_TEMPLATE_ID]
                                     when TravelClaim::Response::CODE_BTSSS_TIMEOUT
                                       [Constants::CIE_STATSD_BTSSS_TIMEOUT, Constants::CIE_TIMEOUT_TEMPLATE_ID]
                                     else
                                       [Constants::CIE_STATSD_BTSSS_ERROR, Constants::CIE_ERROR_TEMPLATE_ID]
                                     end
                                   end

      StatsD.increment(statsd_metric)
      [claim_number, template_id]
    end
    # rubocop:enable Metrics/MethodLength
  end
end
