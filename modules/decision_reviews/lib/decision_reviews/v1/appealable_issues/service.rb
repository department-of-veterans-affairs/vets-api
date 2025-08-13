# lib/decision_reviews/v1/appealable_issues/service.rb
# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'common/exceptions/forbidden'
require 'common/exceptions/schema_validation_errors'
require 'decision_reviews/v1/appealable_issues/configuration'
require 'decision_reviews/v1/service_exception'
require 'decision_reviews/v1/constants'
require 'decision_reviews/v1/supplemental_claim_services'
require 'decision_reviews/v1/logging_utils'

module DecisionReviews
  module V1
    module AppealableIssues
      class Service < Common::Client::Base
        include DecisionReviews::V1::LoggingUtils
        include Common::Client::Concerns::Monitoring

        configuration DecisionReviews::V1::AppealableIssues::Configuration

        STATSD_KEY_PREFIX = 'api.decision_reviews.appealable_issues'

        ##
        # Get appealable issues for higher level reviews
        # Uses 'compensation' as the default benefit type since it's the most common
        #
        # @param user [User] Veteran who the form is in regard to
        # @param [String] receipt_date - Receipt date in YYYY-MM-DD format
        # @param [String] benefit_type - Type of benefit (optional, defaults to 'compensation')
        # @return [Hash] Response containing appealable issues data
        #
        def get_higher_level_review_issues(user:, receipt_date:, benefit_type: 'compensation')
          with_monitoring_and_error_handling do
            response = config.get_higher_level_review_issues(
              icn: user.icn.presence,
              receipt_date:,
              benefit_type:
            )

            handle_response(response, 'higher_level_review_issues')
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
            path = "contestable_issues/supplemental_claims?benefit_type=#{benefit_type}"
            common_log_params = { key: :get_contestable_issues, form_id: '995', user_uuid: user.uuid,
                                  upstream_system: 'Lighthouse (New Appealable Issues API)' }
            begin
              response = config.get_supplemental_claim_issues(
                icn: user.icn.presence, # you can uncomment and use "1012832025V743496" for testing
                benefit_type:
              )
              log_formatted(**common_log_params.merge(is_success: true, status_code: response.status, body: '[Redacted]'))
            rescue => e
              # We can freely log Lighthouse's error responses because they do not include PII or PHI.
              # See https://developer.va.gov/explore/api/decision-reviews/docs?version=v1.
              log_formatted(**common_log_params.merge(error_log_params(e)))
              raise e
            end

            handle_response(response, 'supplemental_claim_issues')
          end
        end

        # Get appealable issues for notices of disagreement
        # Uses 'compensation' as the default benefit type since it's the most common
        #
        # @param user [User] Veteran who the form is in regard to
        # @param [String] receipt_date - Receipt date in YYYY-MM-DD format
        # @param [String] benefit_type - Type of benefit (optional, ignored by LH)
        # @return [Hash] Response containing appealable issues data
        #
        def get_notice_of_disagreement_issues(user:, receipt_date:)
          with_monitoring_and_error_handling do
            response = config.get_supplemental_claim_issues(
              icn: user.icn.presence,
              receipt_date:
            )
            handle_response(response, 'supplemental_claim_issues')
          end
        end

        def handle_response(response, error_key)
          raise_schema_error_unless_200_status response.status
          # validate_against_schema(
          #   json: response.body,
          #   schema: GET_CONTESTABLE_ISSUES_RESPONSE_SCHEMA,
          #   append_to_error_class: ' (NOD_V1)'
          # )
          response
        end

        ##
        # Common method used by both monitoring approaches
        #
        def with_monitoring_and_error_handling(&)
          with_monitoring(2, &)
        rescue => e
          handle_error(error: e)
        end

        def handle_error(error:, message: nil)
        # save_and_log_error(error:, message:)
        source_hash = { source: "#{error.class} raised in #{self.class}" }
        raise case error
              when Faraday::ParsingError
                DecisionReviews::V1::ServiceException.new key: 'DR_502', response_values: source_hash
              when Common::Client::Errors::ClientError
                Sentry.set_extras(body: error.body, status: error.status)
                if common_exceptions_flag_enabled? && ERROR_MAP.key?(error.status)
                  ERROR_MAP[error.status].new(source_hash.merge(detail: error.body))
                elsif error.status == 403
                  Common::Exceptions::Forbidden.new source_hash
                else
                  DecisionReviews::V1::ServiceException.new(key: "DR_#{error.status}", response_values: source_hash,
                                                            original_status: error.status, original_body: error.body)
                end
              else
                error
              end
        end

        def common_exceptions_flag_enabled?
          Flipper.enabled? :decision_review_service_common_exceptions_enabled
        end

        def raise_schema_error_unless_200_status(status)
          return if status == 200

          raise Common::Exceptions::SchemaValidationErrors, ["expecting 200 status received #{status}"]
        end

        def validate_against_schema(json:, schema:, append_to_error_class:)
          # Implement schema validation similar to your existing service
          # This is a placeholder - use your existing schema validation logic
          Rails.logger.debug("Schema validation for #{schema}#{append_to_error_class}")
        end

        def log_formatted(**params)
          Rails.logger.info("Decision Reviews Appealable Issues API", params)
        end

        def error_log_params(error)
          {
            is_success: false,
            response_error: error
          }
        end
      end
    end
  end
end
