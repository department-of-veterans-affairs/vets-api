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

        ERROR_MAP = {
          504 => Common::Exceptions::GatewayTimeout,
          503 => Common::Exceptions::ServiceUnavailable,
          502 => Common::Exceptions::BadGateway,
          500 => Common::Exceptions::ExternalServerInternalServerError,
          429 => Common::Exceptions::TooManyRequests,
          422 => Common::Exceptions::UnprocessableEntity,
          413 => Common::Exceptions::PayloadTooLarge,
          404 => Common::Exceptions::ResourceNotFound,
          403 => Common::Exceptions::Forbidden,
          401 => Common::Exceptions::Unauthorized,
          400 => Common::Exceptions::BadRequest
        }.freeze

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
              log_formatted(**common_log_params.merge(is_success: true, status_code: response.status, body: '[Redacted]'))
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
              log_formatted(**common_log_params.merge(is_success: true, status_code: response.status, body: '[Redacted]'))
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
              log_formatted(**common_log_params.merge(is_success: true, status_code: response.status, body: '[Redacted]'))
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

        def handle_response(response, error_key = '')
          raise_schema_error_unless_200_status response.status
          validate_against_schema(
            json: response.body,
            schema: GET_CONTESTABLE_ISSUES_RESPONSE_SCHEMA,
            append_to_error_class: " #{error_key}"
          )
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

        def save_error_details(error)
          PersonalInformationLog.create!(
            error_class: "#{self.class.name}#save_error_details exception #{error.class} (DECISION_REVIEW_V1)",
            data: { error: Class.new.include(FailedRequestLoggable).exception_hash(error) }
          )
        end

        def log_error_details(error:, message: nil)
          info = {
            message:,
            error_class: error.class,
            error:
          }
          ::Rails.logger.info(info)
        end

        def error_log_params(error)
          log_params = { is_success: false, response_error: error }
          log_params[:body] = error.body if error.try(:status) == 422
          log_params
        end

        def handle_error(error:, message: nil)
          save_and_log_error(error:, message:)
          source_hash = { source: "#{error.class} raised in #{self.class}" }

          raise case error
                when Faraday::ParsingError
                  DecisionReviews::V1::ServiceException.new key: 'DR_502', response_values: source_hash
                when Common::Client::Errors::ClientError
                  error_status = error.status

                  if ERROR_MAP.key?(error_status)
                    ERROR_MAP[error_status].new(source_hash.merge(detail: error.body))
                  elsif error_status == 403
                    Common::Exceptions::Forbidden.new source_hash
                  else
                    DecisionReviews::V1::ServiceException.new(key: "DR_#{error_status}", response_values: source_hash,
                                                              original_status: error_status, original_body: error.body)
                  end
                else
                  error
                end
        end

        def save_and_log_error(error:, message:)
          save_error_details(error)
          log_error_details(error:, message:)
        end

        def validate_against_schema(json:, schema:, append_to_error_class:)
          errors = JSONSchemer.schema(schema).validate(json).to_a
          return if errors.empty?

          raise Common::Exceptions::SchemaValidationErrors, remove_pii_from_json_schemer_errors(errors)
        rescue => e
          PersonalInformationLog.create!(
            error_class: "#{self.class.name}#validate_against_schema exception #{e.class}#{append_to_error_class}",
            data: {
              json:, schema:, errors:,
              error: Class.new.include(FailedRequestLoggable).exception_hash(e)
            }
          )

          raise
        end

        def raise_schema_error_unless_200_status(status)
          return if status == 200

          raise Common::Exceptions::SchemaValidationErrors, ["expecting 200 status received #{status}"]
        end

        def remove_pii_from_json_schemer_errors(errors)
          errors.map { |error| error.slice 'data_pointer', 'schema', 'root_schema' }
        end
      end
    end
  end
end
