# frozen_string_literal: true

require 'common/client/concerns/monitoring'

module Caseflow
  ##
  # Proxy Service for appeals in Caseflow.
  #
  # @example Create a service and fetching caseflow for a user
  #   caseflow_response = Caseflow::Service.new.get_appeals(user)
  #
  class Service < Common::Client::Base
    include SentryLogging
    include Common::Client::Monitoring

    configuration Caseflow::Configuration

    STATSD_KEY_PREFIX = 'api.appeals'
    CASEFLOW_V2_API_PATH = '/api/v2/appeals'
    CASEFLOW_V3_API_PATH = '/api/v3/decision_review/'
    DEFAULT_HEADERS = { 'Authorization' => "Token token=#{Settings.caseflow.app_token}" }.freeze

    ##
    # Returns caseflow data for a user by their SSN.
    #
    # @param user [User] The user object, usually the `@current_user` from a controller.
    # @param additional_headers [Hash] Any additional HTTP headers you want to include in the request.
    # @return [Caseflow::Responses::Caseflow] Response object that includes the body.
    #
    def get_appeals(user, additional_headers = {})
      with_monitoring do
        response = perform(
          :get,
          CASEFLOW_V2_API_PATH,
          {},
          request_headers(additional_headers.merge('ssn' => user.ssn))
        )
        Caseflow::Responses::Caseflow.new(response.body, response.status)
      end
    end

    ##
    # Returns contestable issues for a veteran.
    #
    # @param headers [Hash] Headers to include (in addition to the caseflow api token).
    # @return [Hash] Response object.
    #
    def get_contestable_issues(headers)
      with_monitoring do
        perform(:get, "#{CASEFLOW_V3_API_PATH}contestable_issues", {}, request_headers(headers))
      end
    end

    ##
    # Create a HLR.
    #
    # @param body [Hash] The HLR's attributes. See modules/appeals_api/app/swagger/v1/decision_reviews.yaml
    # @return [Hash] Response object.
    #
    def create_higher_level_review(body)
      with_monitoring do
        perform(:post, "#{CASEFLOW_V3_API_PATH}higher_level_reviews", body, request_headers)
      end
    end

    ##
    # Pings the Caseflow health check endpoint.
    #
    # @return [Faraday::Response] Faraday response instance.
    #
    def healthcheck
      with_monitoring do
        perform(:get, '/health-check', nil)
      end
    end

    private

    def request_headers(additional_headers = {})
      DEFAULT_HEADERS.merge(additional_headers)
    end
  end
end
