# frozen_string_literal: true

module DecisionReview
  module PdfValidation
    class Configuration < DecisionReview::Configuration
      ##
      # @return [String] Base path for PDF validation URL.
      #
      def base_path
        Settings.decision_review.pdf_validation.url
      end

      ##
      # @return [String] Service name to use in breakers and metrics.
      #
      def service_name
        'DecisionReview::PDFValidation'
      end

      ##
      # @return [Hash] The basic headers required for any decision review API call.
      #
      def self.base_request_headers
        # Can use regular Decision Reviews API key in lower environments
        return super unless Rails.env.production?

        # Since we're using the `uploads/validate_document` endpoint under Benefits Intake API,
        # we need to use their API key. This is pulled from BenefitsIntakeService::Configuration
        api_key = Settings.benefits_intake_service.api_key || Settings.form526_backup.api_key
        super.merge('apiKey' => api_key)
      end

      ##
      # Creates the a connection with parsing json and adding breakers functionality.
      #
      # @return [Faraday::Connection] a Faraday connection instance.
      #
      def connection
        @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use(:breakers, service_name:)
          faraday.use      Faraday::Response::RaiseError

          faraday.response :betamocks if mock_enabled?
          faraday.response :json
          faraday.adapter Faraday.default_adapter
        end
      end
    end
  end
end
