# frozen_string_literal: true

module ClaimsApi
  module BGSClient
    class << self
      ##
      # Invokes the given BGS SOAP service action with the given payload and
      # returns a result containing a success payload or a fault.
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
      #   definition =
      #     BGSClient::ServiceAction::Definition::
      #       ManageRepresentativeService::
      #       ReadPoaRequest.instance
      #
      #   BGSClient.perform_request(
      #     definition:,
      #     body:
      #   )
      #
      # @param definition [BGSClient::ServiceAction::Definition] a value object that
      #   identifies a particular BGS SOAP service action by way of:
      #   `{.service.path, .service.namespaces, .action.name}`
      #
      # @param body [String, #to_xml, #to_s] the action payload
      #
      # @param external_id [BGSClient::ServiceAction::ExternalId] a value object that
      #   arbitrarily self-identifies ourselves to BGS as its caller by:
      #   `{.external_uid, .external_key}`
      #
      # @return [BGSClient::ServiceAction::Request::Result<Hash, BGSClient::ServiceAction::Request::Fault>]
      #   the response payload of a successful request, or the fault object of a
      #   failed request
      def perform_request(
        definition:, body:,
        external_id: ServiceAction::ExternalId::DEFAULT
      )
        ServiceAction
          .const_get(:Request)
          .new(definition:, external_id:)
          .perform(body)
      end

      ##
      # Reveals the momemtary health of a BGS service by attempting to request
      # its WSDL and returning the HTTP status code of the response.
      #
      # @example
      #   definition =
      #     BGSClient::ServiceAction::Definition::
      #       ManageRepresentativeService.instance
      #
      #   BGSClient.healthcheck(definition)
      #
      # @param definition [ServiceAction::Definition::Service] a value object
      #   that identifies a particular BGS SOAP service by way of:
      #   `{.path, .namespaces}`
      #
      # @return [Integer] HTTP status code
      def healthcheck(definition)
        connection = build_connection
        response = fetch_wsdl(connection, definition.path)
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
