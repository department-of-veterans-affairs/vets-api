# frozen_string_literal: true

module Logging
  class Sidekiq < Monitor
    def initialize(service)
      @service = service
      super(@service)
    end

    # ##
    # log info request
    #
    # @param message [String]
    # @param metric [String]
    # @param claim [SavedClaim]
    # @param benefits_intake_uuid [FormSubmissions]
    # @param user_account_uuid [User]
    # @param additional_context [Hash]
    #
    # rubocop:disable Metrics/ParameterLists
    def track_claim_submission(message, metric, claim, benefits_intake_uuid,
                               user_account_uuid, additional_context, call_location: nil)
      function, file, line = parse_caller(call_location)

      StatsD.increment(metric)
      Rails.logger.info(message.to_s,
                        {
                          statsd: metric,
                          user_account_uuid:,
                          claim_id: claim&.id,
                          benefits_intake_uuid: benefits_intake_uuid,
                          confirmation_number: claim&.confirmation_number,
                          additional_context:,
                          function:,
                          file:,
                          line:
                        })
    end

    # ##
    # log warn request
    #
    # @param message [String]
    # @param metric [String]
    # @param claim [SavedClaim]
    # @param benefits_intake_uuid [FormSubmissions]
    # @param user_account_uuid [User]
    # @param additional_context [Hash]
    #
    def track_claim_submission_warn(message, metric, claim, benefits_intake_uuid,
                                    user_account_uuid, additional_context, call_location: nil)
      function, file, line = parse_caller(call_location)

      StatsD.increment(metric)
      Rails.logger.warn(message.to_s,
                        {
                          statsd: metric,
                          user_account_uuid:,
                          claim_id: claim&.id,
                          benefits_intake_uuid: benefits_intake_uuid,
                          confirmation_number: claim&.confirmation_number,
                          additional_context:,
                          function:,
                          file:,
                          line:
                        })
    end

    # ##
    # log error request
    #
    # @param message [String]
    # @param metric [String]
    # @param claim [SavedClaim]
    # @param benefits_intake_uuid [FormSubmissions]
    # @param user_account_uuid [User]
    # @param additional_context [Hash]
    #
    def track_claim_submission_error(message, metric, claim, benefits_intake_uuid,
                                     user_account_uuid, additional_context, call_location: nil)
      function, file, line = parse_caller(call_location)

      StatsD.increment(metric)
      Rails.logger.error(message.to_s,
                         {
                           statsd: metric,
                           user_account_uuid:,
                           claim_id: claim&.id,
                           benefits_intake_uuid: benefits_intake_uuid,
                           confirmation_number: claim&.confirmation_number,
                           additional_context:,
                           function:,
                           file:,
                           line:
                         })
    end
  end
  # rubocop:enable Metrics/ParameterLists
end
