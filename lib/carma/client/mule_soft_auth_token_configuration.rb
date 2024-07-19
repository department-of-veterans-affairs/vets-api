# frozen_string_literal: true

module CARMA
  module Client
    class MuleSoftAuthTokenConfiguration < Common::Client::Configuration::REST
      def connection
        Faraday.new(base_path) do |conn|
          conn.use :breakers
          conn.request :instrumentation, name: service_name
          conn.adapter Faraday.default_adapter
        end
      end

      def service_name
        self.class.name
      end

      def timeout
        settings.key?(:timeout) ? settings.timeout : 10
      end

      def settings
        Settings.form_10_10cg.carma.mulesoft.v2
      end

      private

      def base_path
        "#{settings.auth_token_url}/oauth2/default/v1/token"
      end
    end
  end
end
