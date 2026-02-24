# frozen_string_literal: true

require 'digital_forms_api/configuration'
require 'digital_forms_api/jwt_generator'
require 'digital_forms_api/monitor'
require 'common/client/base'

module DigitalFormsApi
  module Service
    # Base service class for API
    class Base < ::Common::Client::Base
      configuration DigitalFormsApi::Configuration

      def initialize
        # assigning configuration here so subclass will inherit
        self.class.configuration DigitalFormsApi::Configuration
        super
      end

      # @see Common::Client::Base#perform
      def perform(method, path, params, headers = {}, options = {})
        call_location = caller_locations.first # eg. DigitalFormsApi::Service::Files#upload
        headers = headers.merge(request_headers)

        requested_api = endpoint || path.split('/').first
        response = super(method, path, params, headers, options) # returns Faraday::Env

        monitor.track_api_request(method, requested_api, response.status, response.reason_phrase, call_location:)
        response
      rescue => e
        code = e.try(:status) || 500
        monitor.track_api_request(method, requested_api, code, e.message, call_location:)
        raise e
      end

      private

      # create the monitor to be used for _this_ instance
      # @see DigitalFormsApi::Monitor::Service
      def monitor
        @monitor ||= DigitalFormsApi::Monitor::Service.new
      end

      # additional request headers
      def request_headers
        { 'Authorization' => "Bearer #{encode_jwt}" }
      end

      # @return [String] the encoded jwt
      def encode_jwt
        DigitalFormsApi::JwtGenerator.encode_jwt
      end

      # the name for _this_ endpoint
      def endpoint
        nil
      end
    end

    # end Service
  end

  # end DigitalFormsApi
end
