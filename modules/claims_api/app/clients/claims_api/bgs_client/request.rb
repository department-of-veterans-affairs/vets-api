# frozen_string_literal: true

require 'claims_api/claim_logger'

module ClaimsApi
  module BGSClient
    # `private_constant` is used to prevent inheritance that could eventually
    # tempt someone to add extraneous behavior to this, the presumed parent
    # class. Consumers should instead directly interface with
    # `BGSClient.perform_request`, which maintains the sole responsibility of
    # making a request to BGS.
    private_constant :Request

    class Request
      def initialize(service_action:, external_id:)
        @service_action = service_action
        @external_id = external_id
      end

      def perform(body)
        wsdl =
          log_duration('connection_wsdl_get') do
            get_wsdl
          end

        body =
          log_duration('built_request') do
            wsdl = Hash.from_xml(wsdl)
            build_request(body, wsdl)
          end

        response =
          log_duration('connection_post') do
            post(body)
          end

        log_duration('parsed_response') do
          parse_response!(response.body)
        end
      end

      private

      def get_wsdl
        BGSClient.send(
          :get_wsdl,
          connection,
          @service_action
        ).body
      end

      def build_request(body, wsdl)
        headers =
          Envelope::Headers.new(
            ip: client_ip,
            username: Settings.bgs.client_username,
            station_id: Settings.bgs.client_station_id,
            application_name: Settings.bgs.application,
            external_id: @external_id
          )

        Envelope.build(
          namespaces: build_namespaces(wsdl),
          action: @service_action.action_name,
          headers:,
          body:
        )
      end

      def post(body)
        connection.post(@service_action.service_path) do |req|
          req.body = body

          req.headers.merge!(
            'Soapaction' => %("#{@service_action.action_name}"),
            'Content-Type' => 'text/xml;charset=UTF-8',
            'Host' => "#{Settings.bgs.env}.vba.va.gov"
          )
        end
      end

      def parse_response!(body)
        body = Hash.from_xml(body)
        body = body.dig('Envelope', 'Body').to_h
        fault = body['Fault'].to_h

        if fault.present?
          raise Error::BGSFault.new(
            code: fault['faultcode'].to_s.split(':').last,
            message: fault['faultstring'],
            detail: fault['detail'].to_h
          )
        end

        key = "#{@service_action.action_name}Response"
        body[key].to_h
      end

      def build_namespaces(wsdl)
        {}.tap do |value|
          namespace = wsdl.dig('definitions', 'targetNamespace')
          namespace = URI(namespace.to_s)
          value['tns'] = namespace

          @service_action.service_namespaces.to_h.each do |aliaz, path|
            uri = namespace.clone
            uri.path = path
            value[aliaz] = uri
          end
        end
      end

      def client_ip
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
      end

      def connection
        @connection ||=
          BGSClient.send(:build_connection) do |conn|
            # Should all of this connection configuration really not be
            # involved in the BGS service healthcheck performed by
            # `BGSClient.healthcheck`? Under the hood, that just fetches WSDL
            # which we also do here but with this more sophisticated logic.
            # Maybe we truly don't want `breakers` and `timeout` logic to
            # impact our assessment of service health in that context?
            conn.options.timeout = Settings.bgs.timeout || 120
            conn.use :breakers
            conn.use WrapError
          end
      end

      # The underlying Faraday exceptions will be the `#cause` of our wrapped
      # exceptions.
      class WrapError < Faraday::Middleware
        def on_error(error)
          error_klass =
            case error
            when Faraday::ConnectionFailed
              Error::ConnectionFailed
            when Faraday::TimeoutError
              Error::TimeoutError
            when Faraday::SSLError
              Error::SSLError
            else
              # The middleware should proceed with its default re-raise
              # behavior.
              return
            end

          detail = "local BGS Faraday Timeout: #{error.message}"
          ClaimsApi::Logger.log('local_bgs', retry: true, detail:)
          raise error_klass
        end
      end

      # Use features of `SemanticLogger` like tags, metrics, benchmarking,
      # appenders (e.g. for statsd?), etc rather than bespoke implementation?
      # https://logger.rocketjob.io/
      def log_duration(event)
        start = now
        yield
      ensure
        duration = (now - start).round(4)
        metric = "api.claims_api.local_bgs.#{event}.duration"
        StatsD.measure(metric, duration, tags: {})

        ClaimsApi::Logger.log(
          'local_bgs',
          # event should be first key in log, duration last
          event:,
          endpoint: @service_action.service_path,
          action: @service_action.action_name,
          duration:
        )
      end

      def now
        ::Process.clock_gettime(
          ::Process::CLOCK_MONOTONIC
        )
      end
    end
  end
end
