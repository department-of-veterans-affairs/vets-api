# frozen_string_literal: true

module VRE
  module Ch31CaseMilestones
    class Configuration < VRE::Configuration
      def connection
        @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
          faraday.use(:breakers, service_name:)
          faraday.response :raise_custom_error, error_prefix: service_name
          faraday.response :betamocks if mock_enabled?
          faraday.response :json, content_type: /\bjson/
          faraday.response :snakecase, symbolize: false
          faraday.adapter Faraday.default_adapter
        end
      end

      def service_name
        'RES_CH31_CASE_MILESTONES'
      end

      private

      def mock_enabled?
        ActiveModel::Type::Boolean.new.cast(Settings.res.ch_31_case_milestones.mock) || false
      end
    end
  end
end
