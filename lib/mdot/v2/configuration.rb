# frozen_string_literal: true

module MDOT::V2
  class Configuration < Common::Client::Configuration::REST
    self.request_types = %i[get post]

    def base_path
      Settings.mdot_v2.url
    end

    def service_name
      'MDOT_V2'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.request :json

        # :raise_custom_error faraday middleware
        #   raise ::ServiceException < Common::Exceptions::BackendServiceException type errors
        #   through Common::Client::Middleware::Response::RaiseCustomError middleware
        #   when response.status&.between?(400, 599)
        faraday.response :raise_custom_error, error_prefix: service_name
        faraday.response :json

        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
