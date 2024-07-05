# frozen_string_literal: true

module CheckIn
  class TravelClaimStatusCheckWorker < TravelClaimBaseWorker
    SUCCESSFUL_CLAIM_STATUSES = ['approved for payment', 'claim paid', 'claim submitted', 'in manual review',
                                 'in-process', 'submitted for payment', 'saved'].freeze
    FAILED_CLAIM_STATUSES = ['appeal', 'closed with no payment', 'denied', 'fiscal rescinded', 'incomplete', 'on hold',
                             'partial payment', 'payment canceled'].freeze

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

      handle_response(claim_status_resp:, facility_type: opts[:facility_type], uuid: opts[:uuid])
    rescue => e
      logger.error({ message: "Error calling BTSSS Service: #{e.message}", method: 'claim_status' }.merge(opts))
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
      claim_response_body = opts[:claim_status_resp].body || []
      claim_response_status = opts[:claim_status_resp].status
      facility_type = opts[:facility_type] || ''
      claim_number = nil

      statsd_metric, template_id = case claim_response_status
                                   when 200
                                     claim_response = begin
                                       Oj.load(claim_response_body)
                                     rescue
                                       claim_response_body
                                     end
                                     if claim_response.size.zero?
                                       logger.info({ message: 'Empty claim status response', uuid: opts[:uuid] })
                                       error_statsd_metric_and_template_id(facility_type:)
                                     else
                                       if claim_response.size > 1
                                         logger.info({ message: 'Multiple claim statuses',
                                                       uuid: opts[:uuid] })
                                       end
                                       claim_number = claim_response.first.with_indifferent_access[:claimNum]&.last(4)
                                       claim_status = claim_response.first.with_indifferent_access[:claimStatus]
                                       if SUCCESSFUL_CLAIM_STATUSES.include?(claim_status.downcase)
                                         success_statsd_metric_and_template_id(facility_type:)
                                       elsif FAILED_CLAIM_STATUSES.include?(claim_status.downcase)
                                         failure_statsd_metric_and_template_id(facility_type:)
                                       else
                                         logger.info({ message: 'Received non-matching claim status', claim_status:,
                                                       uuid: opts[:uuid] })
                                         error_statsd_metric_and_template_id(facility_type:)
                                       end
                                     end
                                   when 408
                                     timeout_statsd_metric_and_template_id(facility_type:)
                                   else
                                     error_statsd_metric_and_template_id(facility_type:)
                                   end
      StatsD.increment(statsd_metric)
      [claim_number, template_id]
    end
    # rubocop:enable Metrics/MethodLength

    private

    def success_statsd_metric_and_template_id(facility_type:)
      case facility_type
      when 'oh'
        [Constants::OH_STATSD_BTSSS_SUCCESS, Constants::OH_SUCCESS_TEMPLATE_ID]
      else
        [Constants::CIE_STATSD_BTSSS_SUCCESS, Constants::CIE_SUCCESS_TEMPLATE_ID]
      end
    end

    def timeout_statsd_metric_and_template_id(facility_type:)
      case facility_type
      when 'oh'
        [Constants::OH_STATSD_BTSSS_TIMEOUT, Constants::OH_TIMEOUT_TEMPLATE_ID]
      else
        [Constants::CIE_STATSD_BTSSS_TIMEOUT, Constants::CIE_TIMEOUT_TEMPLATE_ID]
      end
    end

    def error_statsd_metric_and_template_id(facility_type:)
      case facility_type
      when 'oh'
        [Constants::OH_STATSD_BTSSS_ERROR, Constants::OH_ERROR_TEMPLATE_ID]
      else
        [Constants::CIE_STATSD_BTSSS_ERROR, Constants::CIE_ERROR_TEMPLATE_ID]
      end
    end

    def failure_statsd_metric_and_template_id(facility_type:)
      case facility_type
      when 'oh'
        [Constants::OH_STATSD_BTSSS_CLAIM_FAILURE, Constants::OH_FAILURE_TEMPLATE_ID]
      else
        [Constants::CIE_STATSD_BTSSS_CLAIM_FAILURE, Constants::CIE_FAILURE_TEMPLATE_ID]
      end
    end
  end
end
