# frozen_string_literal: true

module CheckIn
  class TravelClaimSubmissionJob < TravelClaimBaseJob
    def perform(uuid, appointment_date)
      redis_client = TravelClaim::RedisClient.build
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

      claim_number_last_four, template_id = submit_claim(uuid:, appointment_date:, station_number:, facility_type:)
      unless template_id.nil? || claim_number_last_four.nil?
        TravelClaimNotificationJob.perform_async(uuid, appointment_date, template_id, claim_number_last_four)
      end
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
