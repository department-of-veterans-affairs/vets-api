# frozen_string_literal: true

module DecisionReview
  module PdfValidation
    class Configuration < DecisionReview::Configuration
      ##
      # @return [String] Base path for decision review URLs.
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
      # Creates the a connection with parsing json and adding breakers functionality.
      #
      # @return [Faraday::Connection] a Faraday connection instance.
      #
      def connection
        @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use      :breakers
          faraday.use      Faraday::Response::RaiseError

          faraday.response :betamocks if mock_enabled?
          faraday.response :json
          faraday.adapter Faraday.default_adapter
        end
      end
    end
  end
end
