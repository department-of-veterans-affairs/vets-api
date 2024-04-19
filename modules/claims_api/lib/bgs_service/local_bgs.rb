# frozen_string_literal: true

# As a work of the United States Government, this project is in the
# public domain within the United States.
#
# Additionally, we waive copyright and related rights in the work
# worldwide through the CC0 1.0 Universal public domain dedication.

require 'claims_api/claim_logger'
require 'claims_api/error/soap_error_handler'
require_relative 'local_bgs/miscellaneous_operations'

module ClaimsApi
  class LocalBGS
    class << self
      def breakers_service
        url = URI.parse(Settings.bgs.url)
        matcher = proc do |request_env|
          request_env.url.host == url.host &&
            request_env.url.port == url.port &&
            request_env.url.path =~ /^#{url.path}/
        end

        Breakers::Service.new(
          name: 'BGS/Claims',
          request_matcher: matcher
        )
      end
    end

    attr_accessor :external_uid, :external_key

    def initialize( # rubocop:disable Metrics/MethodLength
      external_uid: Settings.bgs.external_uid,
      external_key: Settings.bgs.external_key
    )
      @client_ip =
        if Rails.env.test?
          # For all intents and purposes, BGS behaves identically no matter what
          # IP we provide it. So in a test environment, let's just give it a
          # fake so that cassette matching isn't defeated on CI and everyone's
          # computer.
          '127.0.0.1'
        else
          Socket
            .ip_address_list
            .detect(&:ipv4_private?)
            .ip_address
        end

      @ssl_verify_mode =
        if Settings.bgs.ssl_verify_mode == 'none'
          OpenSSL::SSL::VERIFY_NONE
        else
          OpenSSL::SSL::VERIFY_PEER
        end

      @application = Settings.bgs.application
      @client_station_id = Settings.bgs.client_station_id
      @client_username = Settings.bgs.client_username
      @env = Settings.bgs.env
      @mock_response_location = Settings.bgs.mock_response_location
      @mock_responses = Settings.bgs.mock_responses
      @external_uid = external_uid
      @external_key = external_key
      @forward_proxy_url = Settings.bgs.url
      @timeout = Settings.bgs.timeout || 120
      @url = Settings.bgs.url
    end

    def healthcheck(endpoint)
      response = fetch_wsdl(endpoint)
      response.status
    end

    def make_request(endpoint:, action:, body:, key: nil, namespaces: {}, transform_response: true) # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
      begin
        wsdl =
          log_duration(event: 'connection_wsdl_get', endpoint:) do
            fetch_wsdl(endpoint).body
          end

        request_body =
          log_duration(event: 'built_request', endpoint:, action:) do
            wsdl_body = Hash.from_xml(wsdl)
            namespace = wsdl_body.dig('definitions', 'targetNamespace').to_s

            wrap_request_body(
              body,
              action:,
              namespace:,
              namespaces:
            )
          end

        response =
          log_duration(event: 'connection_post', endpoint:, action:) do
            connection.post(endpoint) do |req|
              req.body = request_body

              req.headers.merge!(
                'Content-Type' => 'text/xml;charset=UTF-8',
                'Host' => "#{@env}.vba.va.gov",
                'Soapaction' => %("#{action}")
              )
            end
          end
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
        detail = "local BGS Faraday Timeout: #{e.message}"
        ClaimsApi::Logger.log('local_bgs', retry: true, detail:)

        raise ::Common::Exceptions::BadGateway
      end

      log_duration(event: 'parsed_response', key:) do
        response_body = Hash.from_xml(response.body)
        soap_error_handler.handle_errors!(response_body)

        unwrap_response_body(
          response_body,
          transform: transform_response,
          action:,
          key:
        )
      end
    end

    private

    def fetch_wsdl(endpoint)
      connection.get(endpoint) do |req|
        req.params['WSDL'] = nil
      end
    end

    def wrap_request_body(body, action:, namespace:, namespaces:) # rubocop:disable Metrics/MethodLength
      namespaces =
        namespaces.map do |aliaz, path|
          uri = URI(namespace)
          uri.path = path
          %(xmlns:#{aliaz}="#{uri}")
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
                <wsse:Username>#{@client_username}</wsse:Username>
              </wsse:UsernameToken>
              <vaws:VaServiceHeaders
                xmlns:vaws="http://vbawebservices.vba.va.gov/vawss"
              >
                <vaws:CLIENT_MACHINE>#{@client_ip}</vaws:CLIENT_MACHINE>
                <vaws:STN_ID>#{@client_station_id}</vaws:STN_ID>
                <vaws:applicationName>#{@application}</vaws:applicationName>
                <vaws:ExternalUid>#{@external_uid}</vaws:ExternalUid>
                <vaws:ExternalKey>#{@external_key}</vaws:ExternalKey>
              </vaws:VaServiceHeaders>
            </wsse:Security>
          </env:Header>
          <env:Body>
            <tns:#{action}>#{body}</tns:#{action}>
          </env:Body>
        </env:Envelope>
      EOXML
    end

    def unwrap_response_body(body, action:, key:, transform:)
      keys = ['Envelope', 'Body', "#{action}Response"]
      keys << key if key.present?

      body.dig(*keys).to_h.tap do |value|
        if transform
          value.deep_transform_keys! do |key|
            key.underscore.to_sym
          end
        end
      end
    end

    def soap_error_handler
      ClaimsApi::SoapErrorHandler.new
    end

    def connection
      @connection ||=
        Faraday.new(@url, ssl: { verify_mode: @ssl_verify_mode }) do |f|
          f.use :breakers
          f.adapter Faraday.default_adapter
          f.options.timeout = @timeout
        end
    end

    def log_duration(event: 'default', **extra_params)
      # Who are we to question sidekiq's use of CLOCK_MONOTONIC to avoid negative durations?
      # https://github.com/sidekiq/sidekiq/issues/3999
      start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      result = yield
      duration = (::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - start_time).round(4)

      # event should be first key in log, duration last
      event_for_log = { event: }.merge(extra_params).merge({ duration: })
      ClaimsApi::Logger.log 'local_bgs', **event_for_log
      StatsD.measure("api.claims_api.local_bgs.#{event}.duration", duration, tags: {})
      result
    end
  end
end
