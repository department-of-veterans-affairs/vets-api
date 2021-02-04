# frozen_string_literal: true

Faraday::Response.register_middleware health_quest_errors: HealthQuest::Middleware::Response::Errors
Faraday::Middleware.register_middleware health_quest_logging: HealthQuest::Middleware::HealthQuestLogging

module HealthQuest
  class Configuration < Common::Client::Configuration::REST
    def base_path
      Settings.hqva_mobile.url
    end

    def service_name
      'HEALTHQUEST'
    end

    def rsa_key
      private_key_path =
        Rails.env.development? ? Settings.hqva_mobile.development_key_path : Settings.hqva_mobile.key_path

      @key ||= OpenSSL::PKey::RSA.new(File.read(private_key_path))
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use :breakers
        conn.request :camelcase
        conn.request :json

        if ENV['HEALTH_QUEST_DEBUG'] && !Rails.env.production?
          conn.request(:curl, ::Logger.new(STDOUT), :warn)
          conn.response(:logger, ::Logger.new(STDOUT), bodies: true)
        end

        conn.response :betamocks if mock_enabled?
        conn.response :snakecase
        conn.response :json, content_type: /\bjson$/
        conn.response :health_quest_errors
        conn.use :health_quest_logging
        conn.adapter Faraday.default_adapter
      end
    end

    def mock_enabled?
      [true, 'true'].include?(Settings.hqva_mobile.mock)
    end
  end
end
