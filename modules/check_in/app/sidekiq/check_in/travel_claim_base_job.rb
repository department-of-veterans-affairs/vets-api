# frozen_string_literal: true

require 'sidekiq'
require 'vets/shared_logging'

module CheckIn
  class TravelClaimBaseJob
    include Sidekiq::Job
    include Vets::SharedLogging

    sidekiq_options retry: false

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

    # Helper method for logging with contextual data across all travel claim jobs
    # @param log_level [Symbol] The log level (:info, :error, etc.)
    # @param message [String] The log message
    # @param data [Hash] Additional contextual data to include in the log
    def self.log_with_context(log_level, message, data = {})
      log_data = { message: "#{self}: #{message}" }.merge(data)
      Rails.logger.send(log_level, to_s, log_data)
    end
  end
end
