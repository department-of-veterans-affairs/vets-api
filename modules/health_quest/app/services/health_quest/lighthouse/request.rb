# frozen_string_literal: true

Faraday::Response.register_middleware health_quest_errors: HealthQuest::Middleware::Response::Errors
Faraday::Middleware.register_middleware health_quest_logging: HealthQuest::Middleware::HealthQuestLogging

module HealthQuest
  module Lighthouse
    ##
    # An object responsible for making HTTP calls to the Lighthouse service
    #
    class Request
      ##
      # Builds a Lighthouse::Request instance from a user
      #
      # @return [Lighthouse::Request] an instance of this class
      #
      def self.build
        new
      end

      ##
      # make a HTTP POST call to the lighthouse in order to obtain an access_token
      #
      # @param path [String] the path to POST to
      # @param params [String] URI.encode_www_form parameters
      #
      # @return [Faraday::Response]
      #
      def post(path, params)
        connection.post(path) { |req| req.body = params }
      end

      private

      def connection
        Faraday.new(url:, headers:) do |conn|
          conn.response :health_quest_errors
          conn.use :health_quest_logging
          conn.adapter Faraday.default_adapter
        end
      end

      def url
        Settings.hqva_mobile.lighthouse.url
      end

      def headers
        {
          'Host' => Settings.hqva_mobile.lighthouse.host,
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
      end
    end
  end
end
