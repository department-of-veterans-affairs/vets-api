# frozen_string_literal: true

module CheckIn
  class TravelClaimStatusCheckJob < TravelClaimBaseJob
    SUCCESSFUL_CLAIM_STATUSES = %w[ApprovedForPayment ClaimPaid ClaimSubmitted
                                   InManualReview In-Process Saved SubmittedForPayment].freeze
    FAILED_CLAIM_STATUSES = %w[Appeal ClosedWithNoPayment Denied FiscalRescinded Incomplete OnHold
                               PartialPayment PaymentCanceled].freeze

    def perform(uuid, appointment_date)
      redis_client = TravelClaim::RedisClient.build
      station_number = redis_client.station_number(uuid:)
      facility_type = redis_client.facility_type(uuid:)

      self.class.log_with_context(:info, 'Checking travel claim status', {
                                    appointment_date:,
                                    station_number:,
                                    facility_type:,
                                    status: 'checking'
                                  })

      claim_number, template_id = claim_status(uuid:, appointment_date:, station_number:, facility_type:)

      claim_number_last_four = claim_number&.last(4)

      TravelClaimNotificationJob.perform_async(uuid, appointment_date, template_id, claim_number_last_four || '')
    end

    def claim_status(opts = {})
      uuid, appointment_date, facility_type = opts.values_at(:uuid, :appointment_date, :facility_type)
      check_in_session = CheckIn::V2::Session.build(data: { uuid: })

      claim_status_resp = TravelClaim::Service.build(
        check_in: check_in_session,
        params: { appointment_date:, facility_type: }
      ).claim_status

      handle_response(claim_status_resp:, facility_type:, uuid:)
    rescue => e
      self.class.log_with_context(:error, "Error calling BTSSS Service: #{e.message}",
                                  { method: 'claim_status', status: 'failed' }.merge(opts))
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
      response_body = opts[:claim_status_resp]&.dig(:data, :body)
      status = opts[:claim_status_resp]&.dig(:status)
      facility_type = opts[:facility_type] || ''

      code = if status == 200
               get_code_for_200_response(opts[:claim_status_resp], opts[:uuid])
             else
               opts[:claim_status_resp]&.dig(:data, :code)
             end

      statsd_metric, template_id = facility_type.downcase == 'oh' ? OH_RESPONSES[code] : CIE_RESPONSES[code]

      claim_number = response_body&.first&.with_indifferent_access&.[](:claimNum)

      StatsD.increment(statsd_metric)
      [claim_number, template_id]
    end

    def get_code_for_200_response(claim_status_resp, uuid)
      response_code = claim_status_resp&.dig(:data, :code)

      case response_code
      when TravelClaim::Response::CODE_EMPTY_STATUS
        self.class.log_with_context(:info, 'Received empty claim status response', { status: 'empty_response' })
        TravelClaim::Response::CODE_EMPTY_STATUS
      else
        if response_code == TravelClaim::Response::CODE_MULTIPLE_STATUSES
          self.class.log_with_context(:info, 'Received multiple claim status response', { status: 'multiple_response' })
        end

        response_body = claim_status_resp.dig(:data, :body)
        claim_status = response_body.first.with_indifferent_access[:claimStatus]
        determine_claim_code(claim_status, uuid)
      end
    end

    private

    def determine_claim_code(claim_status, uuid)
      if SUCCESSFUL_CLAIM_STATUSES.include?(claim_status)
        TravelClaim::Response::CODE_CLAIM_APPROVED
      elsif FAILED_CLAIM_STATUSES.include?(claim_status)
        TravelClaim::Response::CODE_CLAIM_NOT_APPROVED
      else
        self.class.log_with_context(:error, 'Received non-matching claim status',
                                    { claim_status:, status: 'non_matching', uuid: })
        TravelClaim::Response::CODE_UNKNOWN_ERROR
      end
    end
  end
end
