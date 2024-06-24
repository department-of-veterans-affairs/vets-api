# frozen_string_literal: true

module CheckIn
  class TravelClaimStatusCheckWorker < TravelClaimBaseWorker
    def perform(uuid, appointment_date)
      redis_client = TravelClaim::RedisClient.build
      mobile_phone = redis_client.patient_cell_phone(uuid:)
      station_number = redis_client.station_number(uuid:)
      facility_type = redis_client.facility_type(uuid:)

      logger.info({
                    message: "Checking travel claim status for #{uuid}, #{appointment_date}, " \
                             "#{station_number}, #{facility_type}",
                    uuid:,
                    appointment_date:,
                    station_number:,
                    facility_type:
                  })

      claim_number, template_id = claim_status(uuid:, appointment_date:, station_number:, facility_type:)

      send_notification(mobile_phone:, appointment_date:, template_id:, claim_number:, facility_type:)
      StatsD.increment(Constants::STATSD_NOTIFY_SUCCESS)
    end

    def claim_status(opts = {})
      check_in_session = CheckIn::V2::Session.build(data: { uuid: opts[:uuid] })

      claim_status_resp = TravelClaim::Service.build(
        check_in: check_in_session,
        params: { appointment_date: opts[:appointment_date] }
      ).claim_status

      handle_response(claim_status_resp:, facility_type: opts[:facility_type])
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
      # claim_response_body = opts[:claim_status_resp].body || []
      claim_response_status = opts[:claim_status_resp].status
      facility_type = opts[:facility_type] || ''
      claim_number = nil

      statsd_metric, template_id = case claim_response_status
                                   when 200
                                   # Log if more than one claim status
                                   # Use the first claim status for processing
                                   # Check for empty response
                                   # Check if claim is successful
                                   # Check if claim is failed
                                   when 408
                                     case facility_type
                                     when 'oh'
                                       [Constants::OH_STATSD_BTSSS_TIMEOUT, Constants::OH_TIMEOUT_TEMPLATE_ID]
                                     else
                                       [Constants::CIE_STATSD_BTSSS_TIMEOUT, Constants::CIE_TIMEOUT_TEMPLATE_ID]
                                     end
                                   else
                                     case facility_type
                                     when 'oh'
                                       [Constants::OH_STATSD_BTSSS_ERROR, Constants::OH_ERROR_TEMPLATE_ID]
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
