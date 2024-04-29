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
        attr_reader :external_id

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
                  @definition
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
                  req.body = request_body
                  req.headers.merge!(
                    'Soapaction' => %("#{@definition.action_name}"),
                    'Content-Type' => 'text/xml;charset=UTF-8',
                    'Host' => "#{Settings.bgs.env}.vba.va.gov"
                  )
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
            {}.tap do |value|
              namespace = URI(namespace)
              value['tns'] = namespace

              @definition.service_namespaces.to_h.each do |aliaz, path|
                uri = namespace.clone
                uri.path = path
                value[aliaz] = uri
              end
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

          headers =
            Envelope::Headers.new(
              ip: client_ip,
              username: Settings.bgs.client_username,
              station_id: Settings.bgs.client_station_id,
              application_name: Settings.bgs.application,
              external_id:
            )

          action = @definition.action_name

          Envelope.generate(
            namespaces:,
            headers:,
            action:,
            body:
          )
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
          @connection ||=
            BGSClient.send(:build_connection) do |conn|
              # Should all of this connection configuration really not be
              # involved in the BGS service healthcheck performed by
              # `BGSClient.healthcheck`? Under the hood, that just fetches WSDL
              # which we also do here but with "smarter" connection config.
              conn.options.timeout = Settings.bgs.timeout || 120
              conn.adapter Faraday.default_adapter
              conn.use :breakers
            end
        end

        # Use features of `SemanticLogger` like tags, metrics, benchmarking,
        # appenders, etc rather than making bespoke implementations?
        # https://logger.rocketjob.io/
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
