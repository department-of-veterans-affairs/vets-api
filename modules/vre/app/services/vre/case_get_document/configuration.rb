# frozen_string_literal: true

module VRE
  module CaseGetDocument
    class Configuration < VRE::Configuration
      def connection
        @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use(:breakers, service_name:)
          faraday.response :raise_custom_error, error_prefix: service_name
          faraday.response :betamocks if mock_enabled?
          faraday.response :snakecase, symbolize: false
          faraday.response :json, content_type: /\bjson/
          faraday.adapter Faraday.default_adapter
        end
      end

      def service_name
        'RES_CASE_GET_DOCUMENT'
      end

      private

      def mock_enabled?
        ActiveModel::Type::Boolean.new.cast(Settings.res.case_get_document.mock) || false
      end
    end
  end
end
