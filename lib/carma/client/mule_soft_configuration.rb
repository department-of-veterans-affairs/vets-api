# frozen_string_literal: true

module CARMA
  module Client
    class MuleSoftConfiguration < Common::Client::Configuration::REST
      def connection
        Faraday.new(base_path, headers: base_request_headers) do |conn|
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
      # setting. Defaults to 60 if unset.
      def timeout
        settings.key?(:timeout) ? settings.timeout : 60
      end

      # @return [Config::Options]
      def settings
        Settings.form_10_10cg.carma.mulesoft
      end

      def base_request_headers
        super.merge(
          'Authorization' => "Bearer #{bearer_token}"
        )
      end

      private

      # @return [String]
      def base_path
        "#{settings.host}/va-carma-caregiver-papi/api/"
      end

      def bearer_token
        @bearer_token ||= CARMA::Client::MuleSoftAuthTokenClient.new.new_bearer_token
      end
    end
  end
end
