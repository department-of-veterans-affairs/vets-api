# frozen_string_literal: true

require 'claims_api/claim_logger'

module ClaimsApi
  module BGSClient
    module ServiceAction
      # `private_constant` is used to prevent inheritance that could eventually
      # tempt someone to add extraneous behavior to this, the parent class.
      # Consumers should instead directly interface with
      # `BGSClient.perform_request`, which maintains the sole responsibility of
      # making a request to BGS.
      private_constant :Request

      class Request
        def initialize(definition:, external_id:)
          @definition = definition
          @external_id = external_id
        end

        def perform(body) # rubocop:disable Metrics/MethodLength
          begin
            wsdl =
              log_duration('connection_wsdl_get') do
                BGSClient.send(
                  :fetch_wsdl,
                  connection,
                  @definition.service_path
                ).body
              end

            request_body =
              log_duration('built_request') do
                wsdl_body = Hash.from_xml(wsdl)
                namespace = wsdl_body.dig('definitions', 'targetNamespace').to_s
                build_request_body(body, namespace:)
              end

            response =
              log_duration('connection_post') do
                connection.post(@definition.service_path) do |req|
                  req.headers['Soapaction'] = %("#{@definition.action_name}")
                  req.body = request_body
                end
              end
          rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
            detail = "local BGS Faraday Timeout: #{e.message}"
            ClaimsApi::Logger.log('local_bgs', retry: true, detail:)
            raise ::Common::Exceptions::BadGateway
          end

          log_duration('parsed_response') do
            response_body = Hash.from_xml(response.body)
            action_body = response_body.dig('Envelope', 'Body').to_h
            fault = get_fault(action_body)

            if fault
              Result.new(
                success: false,
                value: fault
              )
            else
              key = "#{@definition.action_name}Response"
              value = action_body[key].to_h

              Result.new(
                success: true,
                value:
              )
            end
          end
        end

        private

        def build_request_body(body, namespace:) # rubocop:disable Metrics/MethodLength
          namespaces =
            @definition.service_namespaces.map do |aliaz, path|
              uri = URI(namespace)
              uri.path = path
              %(xmlns:#{aliaz}="#{uri}")
            end

          client_ip =
            if Rails.env.test?
              # For all intents and purposes, BGS behaves identically no matter
              # what IP we provide it. So in a test environment, let's just give
              # it a fake IP so that cassette matching isn't defeated on CI and
              # everyone's computer.
              '127.0.0.1'
            else
              Socket
                .ip_address_list
                .detect(&:ipv4_private?)
                .ip_address
            end

          <<~EOXML
            <?xml version="1.0" encoding="UTF-8"?>
            <env:Envelope
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xmlns:tns="#{namespace}"
              xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"
              #{namespaces.join("\n")}
            >
              <env:Header>
                <wsse:Security
                  xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
                >
                  <wsse:UsernameToken>
                    <wsse:Username>#{Settings.bgs.client_username}</wsse:Username>
                  </wsse:UsernameToken>
                  <vaws:VaServiceHeaders
                    xmlns:vaws="http://vbawebservices.vba.va.gov/vawss"
                  >
                    <vaws:CLIENT_MACHINE>#{client_ip}</vaws:CLIENT_MACHINE>
                    <vaws:STN_ID>#{Settings.bgs.client_station_id}</vaws:STN_ID>
                    <vaws:applicationName>#{Settings.bgs.application}</vaws:applicationName>
                    <vaws:ExternalUid>#{@external_id.external_uid}</vaws:ExternalUid>
                    <vaws:ExternalKey>#{@external_id.external_key}</vaws:ExternalKey>
                  </vaws:VaServiceHeaders>
                </wsse:Security>
              </env:Header>
              <env:Body>
                <tns:#{@definition.action_name}>#{body}</tns:#{@definition.action_name}>
              </env:Body>
            </env:Envelope>
          EOXML
        end

        def get_fault(body)
          fault = body['Fault'].to_h
          return if fault.blank?

          message =
            fault.dig('detail', 'MessageException') ||
            fault.dig('detail', 'MessageFaultException')

          Fault.new(
            code: fault['faultcode'].to_s.split(':').last,
            string: fault['faultstring'],
            message:
          )
        end

        def connection
          @connection ||= BGSClient.send(:build_connection)
        end

        def log_duration(event_name)
          start = now
          result = yield
          finish = now

          duration = (finish - start).round(4)
          event = {
            # event should be first key in log, duration last
            event: event_name,
            endpoint: @definition.service_path,
            action: @definition.action_name,
            duration:
          }

          ClaimsApi::Logger.log('local_bgs', **event)
          metric = "api.claims_api.local_bgs.#{event_name}.duration"
          StatsD.measure(metric, duration, tags: {})

          result
        end

        def now
          ::Process.clock_gettime(
            ::Process::CLOCK_MONOTONIC
          )
        end

        Fault =
          Data.define(
            :code,
            :string,
            :message
          )

        # Tiny subset of the API for `Dry::Monads[:result]`. Chose this
        # particularly because some SOAP `500` really isn't error-like, and it
        # is awkward to wrap exception handling for non-exceptional cases.
        class Result
          attr_reader :value

          def initialize(value:, success:)
            @value = value
            @success = success
          end

          def success?
            @success
          end

          def failure?
            !success?
          end
        end
      end
    end
  end
end
