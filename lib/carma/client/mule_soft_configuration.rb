# frozen_string_literal: true

module CARMA
  module Client
    class MuleSoftConfiguration < Common::Client::Configuration::REST
      def connection
        Faraday.new(base_path) do |conn|
          conn.use(:breakers, service_name:)
          conn.request :instrumentation, name: service_name
          conn.options.timeout = timeout
          conn.adapter Faraday.default_adapter
        end
      end

      def service_name
        self.class.name
      end

      # @return [Integer] Value given by configuration key `form_10_10cg.carma.mulesoft.timeout`
      # setting. Defaults to 600 if unset.
      def timeout
        settings.key?(:timeout) ? settings.timeout : 600
      end

      # @return [Config::Options]
      def settings
        Settings.form_10_10cg.carma.mulesoft
      end

      private

      # @return [String]
      def base_path
        "#{settings.host}/va-carma-caregiver-papi/api/"
      end
    end
  end
end
