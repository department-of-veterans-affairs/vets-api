# frozen_string_literal: true

require_relative '../configuration'

Faraday::Middleware.register_middleware health_quest_logging: HealthQuest::Middleware::HealthQuestLogging
Faraday::Response.register_middleware health_quest_errors: HealthQuest::Middleware::Response::Errors

module HealthQuest
  module V1
    class FHIRConfiguration < HealthQuest::Configuration
      def base_path
        "#{Settings.hqva_mobile.url}/vsp/v1/"
      end

      def service_name
        'HealthQuest::FHIR'
      end

      def connection
        Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
          conn.use :breakers

          if ENV['HEALTH_QUEST_DEBUG'] && !Rails.env.production?
            conn.request(:curl, ::Logger.new(STDOUT), :warn)
            conn.response(:logger, ::Logger.new(STDOUT), bodies: true)
          end

          conn.response :betamocks if mock_enabled?
          conn.response :health_quest_errors
          conn.use :health_quest_logging
          conn.adapter Faraday.default_adapter
        end
      end
    end
  end
end
