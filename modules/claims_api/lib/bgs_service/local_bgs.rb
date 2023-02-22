# frozen_string_literal: true

# As a work of the United States Government, this project is in the
# public domain within the United States.
#
# Additionally, we waive copyright and related rights in the work
# worldwide through the CC0 1.0 Universal public domain dedication.

module ClaimsApi
  class LocalBGS
    attr_accessor :external_uid, :external_key

    def initialize(external_uid:, external_key:)
      @application = Settings.bgs.application
      @client_ip = Socket.ip_address_list.detect(&:ipv4_private?).ip_address
      @client_station_id = Settings.bgs.client_station_id
      @client_username = Settings.bgs.client_username
      @env = Settings.bgs.env
      @mock_response_location = Settings.bgs.mock_response_location
      @mock_responses = Settings.bgs.mock_responses
      @external_uid = external_uid || Settings.bgs.external_uid
      @external_key = external_key || Settings.bgs.external_key
      @forward_proxy_url = Settings.bgs.url
      @ssl_verify_mode = Settings.bgs.ssl_verify_mode == 'none' ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
      @timeout = Settings.bgs.timeout || 120
    end

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

    def full_body(action:, body:)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <?xml version="1.0" encoding="UTF-8"?>
          <env:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:tns="http://services.share.benefits.vba.va.gov/" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
          #{header}
          <env:Body>
            <tns:#{action}>
              #{body}
            </tns:#{action}>
          </env:Body>
          </env:Envelope>
      EOXML
      body.to_s
    end

    def parsed_response(res)
      parsed = Hash.from_xml(res.body)
      parsed.dig('Envelope', 'Body', 'findPOAByPtcpntIdResponse', 'return')
            &.deep_transform_keys(&:underscore)
            &.deep_symbolize_keys || {}
    end

    def make_request(endpoint:, action:, body:)
      connection = Faraday::Connection.new(ssl: { verify_mode: @ssl_verify_mode })
      connection.options.timeout = @timeout
      response = connection.post("#{Settings.bgs.url}/#{endpoint}", full_body(action: action, body: body),
                                 {
                                   'Content-Type' => 'text/xml;charset=UTF-8',
                                   'Host' => 'linktest.vba.va.gov', # TODO: is this needed (in prod)?
                                   'Soapaction' => "\"#{action}\""
                                 })

      parsed_response(response)
    end

    def find_poa_by_participant_id(id)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <ptcpntId />
      EOXML

      { ptcpntId: id }.each do |k, v|
        body.xpath("./*[local-name()='#{k}']")[0].content = v
      end

      make_request(endpoint: 'ClaimantServiceBean/ClaimantWebService', action: 'findPOAByPtcpntId', body: body)
    end
  end
end
