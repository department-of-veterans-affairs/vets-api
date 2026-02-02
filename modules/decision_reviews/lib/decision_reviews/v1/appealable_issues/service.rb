# frozen_string_literal: true

require 'common/client/base'
require 'decision_reviews/v1/appealable_issues/configuration'
require 'decision_reviews/v1/concerns/error_handling'
require 'decision_reviews/v1/constants'
require 'decision_reviews/v1/logging_utils'

module DecisionReviews
  module V1
    module AppealableIssues
      class Service < Common::Client::Base
        include DecisionReviews::V1::Concerns::ErrorHandling
        include DecisionReviews::V1::LoggingUtils

        configuration DecisionReviews::V1::AppealableIssues::Configuration

        STATSD_KEY_PREFIX = 'api.decision_reviews.appealable_issues'

        # API paths
        HIGHER_LEVEL_REVIEWS_PATH = 'appealable-issues/higher-level-reviews'
        NOTICE_OF_DISAGREEMENT_PATH = 'appealable-issues/notice-of-disagreements'
        SUPPLEMENTAL_CLAIMS_PATH = 'appealable-issues/supplemental-claims'

        ##
        # Get appealable issues for higher level reviews
        # Uses 'compensation' as the default benefit type since it's the most common
        #
        # @param user [User] Veteran who the form is in regard to
        # @param [String] benefit_type - Type of benefit (optional, defaults to 'compensation')
        # @return [Hash] Response containing appealable issues data
        #
        def get_higher_level_review_issues(user:, benefit_type: 'compensation')
          with_monitoring_and_error_handling do
            common_log_params = { key: :get_contestable_issues, form_id: '996', user_uuid: user.uuid,
                                  upstream_system: 'Lighthouse (New Appealable Issues API)' }
            begin
              query = {
                icn: user.icn,
                benefitType: benefit_type,
                receiptDate: Time.zone.now.strftime('%Y-%m-%d')
              }
              response = perform(:get, HIGHER_LEVEL_REVIEWS_PATH, query, config.auth_headers)
              log_formatted(**common_log_params.merge(is_success: true, status_code: response.status,
                                                      body: '[Redacted]'))
            rescue => e
              # We can freely log Lighthouse's error responses because they do not include PII or PHI.
              # See https://developer.va.gov/explore/api/decision-reviews/docs?version=v1.
              log_formatted(**common_log_params.merge(error_log_params(e)))
              raise e
            end

            handle_response(response, '(HLR_V1)')
          end
        end

        ##
        # Get appealable issues for Notice of Disagreement
        # Uses 'compensation' as the default benefit type since it's the most common
        #
        # @param user [User] Veteran who the form is in regard to
        # @param [String] benefit_type - Type of benefit (optional, defaults to 'compensation')
        # @return [Hash] Response containing appealable issues data
        #
        def get_notice_of_disagreement_issues(user:, benefit_type: 'compensation')
          with_monitoring_and_error_handling do
            common_log_params = { key: :get_contestable_issues, form_id: '10182', user_uuid: user.uuid,
                                  upstream_system: 'Lighthouse (New Appealable Issues API)' }
            begin
              query = {
                icn: user.icn,
                # Fallback to 'compensation' since NOD benefit_type is optional per API docs
                # (required for HLR/SC, but not NOD). Route has no path param, so may be nil.
                benefitType: benefit_type.presence || 'compensation',
                receiptDate: Time.zone.now.strftime('%Y-%m-%d')
              }
              response = perform(:get, NOTICE_OF_DISAGREEMENT_PATH, query, config.auth_headers)
              log_formatted(**common_log_params.merge(is_success: true, status_code: response.status,
                                                      body: '[Redacted]'))
            rescue => e
              # We can freely log Lighthouse's error responses because they do not include PII or PHI.
              # See https://developer.va.gov/explore/api/decision-reviews/docs?version=v1.
              log_formatted(**common_log_params.merge(error_log_params(e)))
              raise e
            end

            handle_response(response, '(NOD_V1)')
          end
        end

        ##
        # Get appealable issues for supplemental claims
        # Uses 'compensation' as the default benefit type since it's the most common
        #
        # @param user [User] Veteran who the form is in regard to
        # @param [String] benefit_type - Type of benefit (required, defaults to 'compensation')
        # @return [Hash] Response containing appealable issues data
        #
        def get_supplemental_claim_issues(user:, benefit_type: 'compensation')
          with_monitoring_and_error_handling do
            common_log_params = { key: :get_contestable_issues, form_id: '995', user_uuid: user.uuid,
                                  upstream_system: 'Lighthouse (New Appealable Issues API)' }
            begin
              query = {
                icn: user.icn,
                benefitType: benefit_type,
                receiptDate: Time.zone.now.strftime('%Y-%m-%d')
              }
              response = perform(:get, SUPPLEMENTAL_CLAIMS_PATH, query, config.auth_headers)
              log_formatted(**common_log_params.merge(is_success: true, status_code: response.status,
                                                      body: '[Redacted]'))
            rescue => e
              # We can freely log Lighthouse's error responses because they do not include PII or PHI.
              # See https://developer.va.gov/explore/api/decision-reviews/docs?version=v1.
              log_formatted(**common_log_params.merge(error_log_params(e)))
              raise e
            end

            handle_response(response, '(SC_V1)')
          end
        end

        private

        ##
        # Handles API response by validating status and schema
        #
        # @param response [Faraday::Response] The API response
        # @param error_key [String] Key to append to error class for identification
        # @return [Faraday::Response] The validated response
        #
        def handle_response(response, error_key = '')
          raise_schema_error_unless_200_status response.status
          validate_against_schema(
            json: response.body,
            schema: GET_CONTESTABLE_ISSUES_RESPONSE_SCHEMA,
            append_to_error_class: " #{error_key}"
          )
          response
        end
      end
    end
  end
end
