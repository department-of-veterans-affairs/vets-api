# frozen_string_literal: true

Faraday::Response.register_middleware health_quest_errors: HealthQuest::Middleware::Response::Errors
Faraday::Middleware.register_middleware health_quest_logging: HealthQuest::Middleware::HealthQuestLogging

module HealthQuest
  module Facilities
    ##
    # An object responsible for making HTTP calls to the Facilities API
    #
    class Request
      ##
      # Builds a Facilities::Request instance
      # @return [Facilities::Request] an instance of this class
      #
      def self.build
        new
      end

      ##
      # HTTP GET call to the Facilities API to retrieve a list of facilities by IDs
      #
      # @param query_params [String]
      # @return [Array]
      #
      def get(query_params)
        resp = connection.get(ids_path) do |req|
          req.params['ids'] = query_params
          req.headers = facilities_headers
        end

        JSON.parse(resp.body).fetch('data', [])
      end

      ##
      # Facilities API request headers
      #
      # @return [Hash]
      #
      def facilities_headers
        { 'Source-App-Name' => 'healthcare_experience_questionnaire' }
      end

      private

      def connection
        Faraday.new(url:) do |conn|
          conn.response :health_quest_errors
          conn.use :health_quest_logging
          conn.adapter Faraday.default_adapter
        end
      end

      def ids_path
        Settings.hqva_mobile.facilities.ids_path
      end

      def url
        Settings.hqva_mobile.facilities.url
      end
    end
  end
end
