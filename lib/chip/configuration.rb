# frozen_string_literal: true

require_relative 'error_middleware'

module Chip
  class Configuration < Common::Client::Configuration::REST
    ##
    # @return [Config::Options] Chip settings object
    #
    def settings
      Settings.chip
    end

    delegate :url, :api_gtwy_id, :base_path, to: :settings

    ##
    # @return [String] service name
    #
    def service_name
      'Chip'
    end

    ##
    # Validate that the tenant_id matches the tenant_name
    #
    # @return [Boolean]
    #
    def valid_tenant?(tenant_name:, tenant_id:)
      settings[tenant_name]&.tenant_id == tenant_id
    end

    ##
    # Creates a Faraday connection with middleware for mapping errors, and adding breakers functionality.
    #
    # @return [Faraday::Connection] a Faraday connection instance.
    #
    def connection
      @conn ||= Faraday.new(url:) do |faraday|
        faraday.use(:breakers, service_name:)
        faraday.request :json

        faraday.response :chip_error
        faraday.response :betamocks if settings.mock

        faraday.adapter Faraday.default_adapter
      end
    end
  end
end
