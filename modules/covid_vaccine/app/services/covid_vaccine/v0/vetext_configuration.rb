# frozen_string_literal: true

require 'common/client/configuration/rest'

module CovidVaccine
  module V0
    class VetextConfiguration < Common::Client::Configuration::REST
      self.read_timeout = Settings.vetext.timeout || 15

      def base_path
        Settings.vetext.url
      end

      def service_name
        'Vetext'
      end

      def connection
        Faraday.new(base_path, headers: base_request_headers, request: request_options) do |c|
          c.use :breakers
          c.request :camelcase
          c.request :json

          if ENV['DEBUG'] && !Rails.env.production?
            c.request(:curl, ::Logger.new(STDOUT), :warn)
            c.response(:logger, ::Logger.new(STDOUT), bodies: true)
          end

          c.response :betamocks if mock_enabled?
          c.response :snakecase
          c.response :json, content_type: /\bjson$/
          c.adapter Faraday.default_adapter
        end
      end

      def mock_enabled?
        [true, 'true'].include?(Settings.vetext.mock)
      end
    end
  end
end
