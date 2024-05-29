# frozen_string_literal: true

module ClaimsApi
  module BGSClient
    class << self
      ##
      # @param action [BGSClient::Definitions::Action]
      # @param body [String, #to_xml, #to_s] (nil)
      # @param external_id [BGSClient::ExternalId] (BGSClient::ExternalId::DEFAULT)
      #
      # @yield [xml, data_aliaz] rather than pass in the `body` as a param, the
      #   caller can instead choose to build a body using the xml builder helper
      #   and data namespace alias that we yield
      # @yieldparam xml [Nokogiri::XML::Builder]
      # @yieldparam data_aliaz [String]
      #
      # @return [Hash]
      #
      # @raise [BGSClient::Error, ArgumentError]
      #   One and only one of `body` or `block` is required.
      #
      def perform_request(
        action, body = nil,
        external_id: ExternalId::DEFAULT, &
      )
        const_get(:Request)
          .new(action, external_id:)
          .perform(body, &)
      end

      ##
      # @param service [BGSClient::Definitions::Service]
      # @return [Integer] HTTP status code
      # @raise [Faraday::Error]
      #
      def healthcheck(service)
        connection = build_connection
        connection.get(service.full_path) do |req|
          req.params['WSDL'] = nil
        end.status
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

      def build_connection
        ssl_verify_mode =
          if Settings.bgs.ssl_verify_mode == 'none'
            OpenSSL::SSL::VERIFY_NONE
          else
            OpenSSL::SSL::VERIFY_PEER
          end

        Faraday.new(Settings.bgs.url) do |conn|
          conn.ssl.verify_mode = ssl_verify_mode
          yield(conn) if block_given?
        end
      end
    end

    class ExternalId <
      Data.define(
        :external_uid,
        :external_key
      )
      DEFAULT = new(
        external_uid: Settings.bgs.external_uid,
        external_key: Settings.bgs.external_key
      )
    end
  end
end
