# frozen_string_literal: true

module ClaimsApi
  module BGSClient
    class << self
      def perform_request(definition:, body:, external_id: ServiceAction::ExternalId::DEFAULT)
        ServiceAction.const_get(:Request)
          .new(definition:, external_id:)
          .perform(body)
      end

      def healthcheck(service_path)
        connection = build_connection
        response = fetch_wsdl(connection, service_path)
        response.status
      end

      def breakers_service
        url = URI.parse(Settings.bgs.url)
        request_matcher =
          proc do |request_env|
            request_env.url.host == url.host &&
              request_env.url.port == url.port &&
              request_env.url.path =~ /^#{url.path}/
          end

        Breakers::Service.new(
          name: 'BGS/Claims',
          request_matcher:
        )
      end

      private

      def fetch_wsdl(connection, service_path)
        connection.get(service_path) do |req|
          req.params['WSDL'] = nil
        end
      end

      def build_connection
        ssl_verify_mode =
          if Settings.bgs.ssl_verify_mode == 'none'
            OpenSSL::SSL::VERIFY_NONE
          else
            OpenSSL::SSL::VERIFY_PEER
          end

        Faraday.new(Settings.bgs.url) do |conn|
          conn.ssl.verify_mode = ssl_verify_mode
          conn.options.timeout = Settings.bgs.timeout || 120
          conn.use :breakers

          conn.headers.merge!(
            'Content-Type' => 'text/xml;charset=UTF-8',
            'Host' => "#{Settings.bgs.env}.vba.va.gov"
          )
        end
      end
    end
  end
end
