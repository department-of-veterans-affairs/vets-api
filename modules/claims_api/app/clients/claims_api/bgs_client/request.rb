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
      def initialize(action:, external_id:)
        @action = action
        @external_id = external_id
      end

      def perform(body, &)
        unless [body, block_given?].one? # blank string is counted
          error_message = 'One and only one of `body` or `block` is required'
          raise ArgumentError, error_message
        end

        body =
          log_duration('built_request') do
            body ||= Envelope::Body.build(&)
            build_request(body)
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

      def build_request(body)
        headers =
          Envelope::Headers.new(
            ip: client_ip,
            username: Settings.bgs.client_username,
            station_id: Settings.bgs.client_station_id,
            application_name: Settings.bgs.application,
            external_id: @external_id
          )

        Envelope.build(
          namespace: @action.service.bean.namespace,
          data_namespace: @action.service.bean.data_namespace,
          action: @action.name,
          headers:,
          body:
        )
      end

      def post(body)
        connection =
          BGSClient.send(:build_connection) do |conn|
            # Should all of this connection configuration really not be
            # involved in `BGSClient.healthcheck`? Maybe we truly don't want
            # `breakers` and `timeout` logic to impact our assessment of service
            # health in that context?
            conn.options.timeout = Settings.bgs.timeout || 120
            conn.use :breakers
            conn.use WrapError
          end

        connection.post(@action.service.full_path) do |req|
          req.body = body

          req.headers.merge!(
            'Soapaction' => %("#{@action.name}"),
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

        key = "#{@action.name}Response"
        body[key].to_h
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
              # The middleware should proceed with its default re-raise behavior.
              return
            end

          detail = "local BGS Faraday Timeout: #{error.message}"
          ClaimsApi::Logger.log('local_bgs', retry: true, detail:)
          raise error_klass
        end
      end

      def client_ip
        # For all intents and purposes, BGS behaves identically no matter what
        # IP we provide it. So in a test environment, let's just give it a fake
        # IP so that cassette matching isn't defeated on CI and everyone's
        # computer.
        return '127.0.0.1' if Rails.env.test?

        Socket
          .ip_address_list
          .detect(&:ipv4_private?)
          .ip_address
      end

      # Use features of `SemanticLogger` like tags, metrics, benchmarking,
      # appenders (e.g. for statsd?), etc rather than a bespoke implementation?
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
          endpoint: @action.service.full_path,
          action: @action.name,
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
