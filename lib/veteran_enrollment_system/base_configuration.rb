# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/json_parser'

module VeteranEnrollmentSystem
  # Base configuration for Veteran Enrollment System services
  # Provides common functionality for all VES endpoints
  class BaseConfiguration < Common::Client::Configuration::REST
    def base_path
      "#{Settings.veteran_enrollment_system.host}/"
    end

    def service_name
      'VeteranEnrollmentSystem'
    end

    # The base request headers required for any VES API call
    def self.base_request_headers
      super.merge('apiKey' => api_key)
    end

    # Sets the API key for the configuration. This can be overridden
    # by the subclass so that each configuration can have its own API key
    # Example:
    #
    # class AssociationsConfiguration < VeteranEnrollmentSystem::BaseConfiguration
    #   def self.api_key_path
    #     :associations
    #   end
    # end
    # @param [Symbol, String] api_key_path The path to the API key in the config/settings.yml file
    def self.api_key(api_key_path = nil)
      return nil if self == VeteranEnrollmentSystem::BaseConfiguration
      raise 'api_key_path must be defined in subclass' unless respond_to?(:api_key_path) && api_key_path.present?

      Settings.veteran_enrollment_system.send(api_key_path).api_key
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use(:breakers, service_name:)
        conn.request :json
        conn.options.open_timeout = Settings.veteran_enrollment_system.open_timeout
        conn.options.timeout = Settings.veteran_enrollment_system.timeout
        conn.response :json_parser
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
