# frozen_string_literal: true

module ClaimsApi
  module BGSClient
    class << self
      ##
      # Invokes the given BGS SOAP service action with the given payload and
      # returns a result containing a success payload, raises a wrapper
      # around a Faraday error, or raises a BGS fault.
      #
      # @example Perform a request to BGS at:
      #   /VDC/ManageRepresentativeService(readPOARequest)
      #
      #   body = <<~EOXML
      #     <data:SecondaryStatusList>
      #       <SecondaryStatus>New</SecondaryStatus>
      #     </data:SecondaryStatusList>
      #     <data:POACodeList>
      #       <POACode>012</POACode>
      #     </data:POACodeList>
      #   EOXML
      #
      #   service_action =
      #     BGSClient::ServiceAction::
      #       ManageRepresentativeService::
      #       ReadPoaRequest
      #
      #   BGSClient.perform_request(
      #     service_action:,
      #     body:
      #   )
      #
      # @param service_action [BGSClient::ServiceAction] a value object that
      #   identifies a particular BGS SOAP service action by way of:
      #   `{.service_path, .service_namespaces, .action_name}`
      #
      # @param body [String, #to_xml, #to_s] the action payload
      #
      # @param external_id [BGSClient::ExternalId] a value object
      #   that arbitrarily self-identifies ourselves to BGS as its caller by:
      #   `{.external_uid, .external_key}`
      #
      # @return [Hash] the response payload of a successful request
      #
      # @raise [BGSClient::Error] Either a minimal wrapper around `#cause` of
      #   `Faraday::Error` or a `BGSClient::Error::BGSFault` when the BGS
      #   response has a fault object
      def perform_request(
        service_action:, body:,
        external_id: ExternalId::DEFAULT
      )
        const_get(:Request)
          .new(service_action:, external_id:)
          .perform(body)
      end

      ##
      # Reveals the momentary health of a BGS service by attempting to request
      # its WSDL and returning the HTTP status code of the response.
      #
      # @example
      #   service_action =
      #     BGSClient::ServiceAction::
      #       ManageRepresentativeService::
      #       ReadPoaRequest
      #
      #   BGSClient.healthcheck(service_action)
      #
      # @param service_action [BGSClient::ServiceAction] a value object that
      #   identifies a particular BGS SOAP service action by way of:
      #   `{.service_path, .service_namespaces, .action_name}`
      #
      # @return [Integer] HTTP status code
      #
      # @raise [Faraday::Error]
      #
      # @todo We could also introduce the notion of just the service definition
      #   in our central repository of definitions so that:
      #   1. Service action definitions and other code would be able to refer to
      #      them
      #   2. We could improve this API so that it doesn't need to receive
      #      extraneous action information.
      #  But this is fine for now
      def healthcheck(service_action)
        connection = build_connection
        response = get_wsdl(connection, service_action)
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

      def get_wsdl(connection, service_action)
        connection.get(service_action.service_path) do |req|
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
