# frozen_string_literal: true

require 'common/client/configuration/rest'

module VRE
  class Configuration < Common::Client::Configuration::REST
    # def connection
    #   @conn ||= Faraday.new(base_path, headers: request_headers request: request_options) do |faraday|
    #     faraday.use :breakers
    #     faraday.use Faraday::Response::RaiseError
    #     faraday.response :betamocks if mock_enabled?
    #     faraday.response :snakecase, symbolize: false
    #     faraday.response :json, content_type: /\bjson/
    #     faraday.adapter Faraday.default_adapter
    #   end
    # end

    def request_headers
      {
        'Authorization': "Bearer #{get_token}"
      }.freeze
    end

    def mock_enabled?
      Settings.veteran_readiness_and_employment.mock_ch_31 || false
    end

    def base_path
      Settings.veteran_readiness_and_employment.base_url
    end

    def service_name
      'VeteranReadinessEmployment'
    end
  end
end
