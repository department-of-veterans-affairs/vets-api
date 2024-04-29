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
    attr_accessor :external_uid, :external_key

    # rubocop:disable Metrics/MethodLength
    def initialize(external_uid:, external_key:)
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
      @external_uid = external_uid || Settings.bgs.external_uid
      @external_key = external_key || Settings.bgs.external_key
      @forward_proxy_url = Settings.bgs.url
      @timeout = Settings.bgs.timeout || 120
    end
    # rubocop:enable Metrics/MethodLength

    def self.breakers_service
      url = Settings.bgs.url
      path = URI.parse(url).path
      host = URI.parse(url).host
      port = URI.parse(url).port
      matcher = proc do |request_env|
        request_env.url.host == host &&
          request_env.url.port == port &&
          request_env.url.path =~ /^#{path}/
      end

      Breakers::Service.new(
        name: 'BGS/Claims',
        request_matcher: matcher
      )
    end

    def bean_name
      raise 'Not Implemented'
    end

    def healthcheck(endpoint)
      connection = Faraday::Connection.new(ssl: { verify_mode: @ssl_verify_mode })
      wsdl = connection.get("#{Settings.bgs.url}/#{endpoint}?WSDL")
      wsdl.status
    end

    private

    def header # rubocop:disable Metrics/MethodLength
      # Stock XML structure {{{
      header = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <env:Header>
          <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
            <wsse:UsernameToken>
              <wsse:Username></wsse:Username>
            </wsse:UsernameToken>
            <vaws:VaServiceHeaders xmlns:vaws="http://vbawebservices.vba.va.gov/vawss">
              <vaws:CLIENT_MACHINE></vaws:CLIENT_MACHINE>
              <vaws:STN_ID></vaws:STN_ID>
              <vaws:applicationName></vaws:applicationName>
              <vaws:ExternalUid ></vaws:ExternalUid>
              <vaws:ExternalKey></vaws:ExternalKey>
            </vaws:VaServiceHeaders>
          </wsse:Security>
        </env:Header>
      EOXML

      { Username: @client_username, CLIENT_MACHINE: @client_ip,
        STN_ID: @client_station_id, applicationName: @application,
        ExternalUid: @external_uid, ExternalKey: @external_key }.each do |k, v|
        header.xpath(".//*[local-name()='#{k}']")[0].content = v
      end
      header.to_s
    end

    def full_body(action:, body:, namespace:, namespaces:)
      namespaces =
        namespaces.map do |aliaz, path|
          uri = URI(namespace)
          uri.path = path
          %(xmlns:#{aliaz}="#{uri}")
        end

      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <?xml version="1.0" encoding="UTF-8"?>
          <env:Envelope
            xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xmlns:tns="#{namespace}"
            xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"
            #{namespaces.join("\n")}
          >
          #{header}
          <env:Body>
            <tns:#{action}>#{body}</tns:#{action}>
          </env:Body>
          </env:Envelope>
      EOXML
      body.to_s
    end

    def parsed_response(response, action:, key:, transform:)
      body = Hash.from_xml(response.body)
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

    def make_request(endpoint:, action:, body:, key: nil, namespaces: {}, transform_response: true) # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
      connection = log_duration event: 'establish_ssl_connection' do
        Faraday::Connection.new(ssl: { verify_mode: @ssl_verify_mode }) do |f|
          f.use :breakers
          f.adapter Faraday.default_adapter
        end
      end
      connection.options.timeout = @timeout

      begin
        wsdl = log_duration(event: 'connection_wsdl_get', endpoint:) do
          connection.get("#{Settings.bgs.url}/#{endpoint}?WSDL")
        end

        url = "#{Settings.bgs.url}/#{endpoint}"
        namespace = Hash.from_xml(wsdl.body).dig('definitions', 'targetNamespace').to_s
        body = full_body(action:, body:, namespace:, namespaces:)
        headers = {
          'Content-Type' => 'text/xml;charset=UTF-8',
          'Host' => "#{@env}.vba.va.gov",
          'Soapaction' => %("#{action}")
        }

        response = log_duration(event: 'connection_post', endpoint:, action:) do
          connection.post(url, body, headers)
        end
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
        ClaimsApi::Logger.log('local_bgs',
                              retry: true,
                              detail: "local BGS Faraday Timeout: #{e.message}")
        raise ::Common::Exceptions::BadGateway
      end
      soap_error_handler.handle_errors(response) if response

      log_duration(event: 'parsed_response', key:) do
        parsed_response(response, action:, key:, transform: transform_response)
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

    def soap_error_handler
      ClaimsApi::SoapErrorHandler.new
    end
  end
end
