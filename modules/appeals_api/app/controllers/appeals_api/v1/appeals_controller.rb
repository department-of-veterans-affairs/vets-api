# frozen_string_literal: true

module AppealsApi
  module V1
    class AppealsController < AppealsApi::ApplicationController
      include AppealsApi::CaseflowRequest
      include AppealsApi::OpenidAuth

      skip_before_action :authenticate
      before_action :validate_icn_parameter, only: %i[index]

      ICN_REGEX = /^[0-9]{10}V[0-9]{6}$/
      OAUTH_SCOPES = {
        GET: %w[veteran/AppealsStatus.read representative/AppealsStatus.read system/AppealsStatus.read]
      }.freeze

      def index
        render json: caseflow_response.body, status: caseflow_response.status
      end

      private

      def required_header(name)
        value = request.headers[name]
        raise(Common::Exceptions::BadRequest, detail: "Header '#{name}' is required") if value.blank?

        value
      end

      def ssn
        @ssn ||= icn_to_ssn!(params[:icn])
      end

      def va_user
        required_header('X-VA-User')
      end

      def caseflow_request_headers
        { 'Consumer' => request.headers['X-Consumer-Username'], 'VA-User' => required_header('X-VA-User') }
      end

      def log_caseflow_request_details
        hashed_ssn = Digest::SHA2.hexdigest(ssn)
        Rails.logger.info('Caseflow Request', 'va_user' => va_user, 'lookup_identifier' => hashed_ssn)
      end

      def log_caseflow_response(res)
        Rails.logger.info(
          'Caseflow Response',
          {
            'va_user' => va_user,
            'first_appeal_id' => res.body.dig('data', 0, 'id'),
            'appeal_count' => res.body['data'].length
          }
        )
      end

      def get_caseflow_response
        log_caseflow_request_details
        res = Caseflow::Service.new.get_appeals(OpenStruct.new(ssn:), caseflow_request_headers)
        log_caseflow_response(res)
        res
      end

      def validate_icn_parameter
        if params[:icn].blank?
          raise(Common::Exceptions::ParameterMissing, detail: "'icn' parameter is required")
        elsif !ICN_REGEX.match?(params[:icn])
          raise(
            Common::Exceptions::UnprocessableEntity,
            detail: "'icn' parameter has an invalid format. Pattern: #{ICN_REGEX.inspect}"
          )
        end
      end

      def token_validation_api_key
        Settings.dig(:modules_appeals_api, :token_validation, :appeals_status, :api_key)
      end
    end
  end
end
