# frozen_string_literal: true

module AppealsApi
  module V1
    class AppealsController < AppealsApi::ApplicationController
      include AppealsApi::CaseflowRequest
      include AppealsApi::OpenidAuth
      include AppealsApi::IcnParameterValidation

      skip_before_action :authenticate
      before_action :validate_icn_parameter!, only: %i[index]

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
        @ssn ||= icn_to_ssn!(veteran_icn)
      end

      def va_user
        required_header('X-VA-User')
      end

      def caseflow_request_headers
        { 'Consumer' => request.headers['X-Consumer-Username'], 'VA-User' => required_header('X-VA-User') }
      end

      def get_caseflow_response
        Caseflow::Service.new.get_appeals(OpenStruct.new(ssn:), caseflow_request_headers)
      end

      def token_validation_api_key
        Settings.dig(:modules_appeals_api, :token_validation, :appeals_status, :api_key)
      end
    end
  end
end
