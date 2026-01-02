# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'caseflow/responses/caseflow'
require 'vets/shared_logging'

module Caseflow
  ##
  # Proxy Service for appeals in Caseflow.
  #
  # @example Create a service and fetching caseflow for a user
  #   caseflow_response = Caseflow::Service.new.get_appeals(user)
  #
  class Service < Common::Client::Base
    include Vets::SharedLogging
    include Common::Client::Concerns::Monitoring

    configuration Caseflow::Configuration

    STATSD_KEY_PREFIX = 'api.appeals'
    CASEFLOW_V2_API_PATH = '/api/v2/appeals'
    CASEFLOW_V3_API_PATH = '/api/v3/decision_reviews'
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
        response = authorized_perform(
          :get,
          CASEFLOW_V2_API_PATH,
          {},
          additional_headers.merge('ssn' => user.ssn)
        )

        # Track null issue descriptions in appeals
        # If we are seeing a lot of these, we will need to take further action
        begin
          appeals = response.body['data']

          handle_appeals_with_null_issue_descriptions(user, appeals) if appeals.present?
        rescue => e
          Rails.logger.error("Logging null description issues for appeals failed: #{e.message}")
        end

        Caseflow::Responses::Caseflow.new(response.body, response.status)
      end
    end

    # Returns caseflow data for a user via their SSN or file_number passed as headers
    def get_legacy_appeals(headers:)
      with_monitoring do
        authorized_perform(
          :get,
          "#{CASEFLOW_V3_API_PATH}/legacy_appeals".chomp('/'),
          {},
          headers
        )
      end
    end

    ##
    # Returns contestable issues for a veteran.
    #
    # @param headers [Hash] Headers to include.
    # @param decision_review_type [String] The type of decision review (appeals (nod), higher_level_reviews, etc)
    # @return [Hash] Response object.
    #
    def get_contestable_issues(headers:, benefit_type:, decision_review_type:)
      with_monitoring do
        authorized_perform(
          :get,
          "#{CASEFLOW_V3_API_PATH}/#{decision_review_type}/contestable_issues/#{benefit_type}".chomp('/'),
          {},
          headers
        )
      end
    end

    ##
    # Create a HLR in Caseflow.
    #
    # @param body [Hash] The HLR's attributes.
    # @return [Hash] Response object.
    #
    def create_higher_level_review(body)
      with_monitoring do
        authorized_perform(:post, "#{CASEFLOW_V3_API_PATH}/higher_level_reviews", body)
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

    def authorized_perform(method, path, params, additional_headers = nil, options = nil)
      perform(method, path, params, DEFAULT_HEADERS.merge(additional_headers || {}), options)
    end

    # Increments statsd metric and logs appeals that have one or more issues with null descriptions
    def handle_appeals_with_null_issue_descriptions(user, appeals)
      appeals_with_null_issue_descriptions = []

      appeals.each do |appeal|
        next unless appeal.dig('attributes', 'issues')

        issues_with_null_description = appeal['attributes']['issues'].select { |issue| issue['description'].nil? }

        if issues_with_null_description.any?
          StatsD.increment("#{STATSD_KEY_PREFIX}.appeals_with_null_issue_descriptions")
          appeals_with_null_issue_descriptions << {
            'id' => appeal['id'],
            'issues' => issues_with_null_description
          }
        end
      end

      if appeals_with_null_issue_descriptions.any?
        log_appeals_with_no_issue_descriptions(user, appeals_with_null_issue_descriptions)
      end
    end

    def log_appeals_with_no_issue_descriptions(user, appeals)
      Rails.logger.warn("Caseflow returned the following appeals with null issue descriptions: #{appeals}")
      PersonalInformationLog.create!(
        data: {
          user:,
          appeals:
        },
        error_class: 'Caseflow AppealsWithNullIssueDescriptions'
      )
    end
  end
end
