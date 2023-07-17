# frozen_string_literal: true

# As a work of the United States Government, this project is in the
# public domain within the United States.
#
# Additionally, we waive copyright and related rights in the work
# worldwide through the CC0 1.0 Universal public domain dedication.

require 'claims_api/claim_logger'
require 'claims_api/error/soap_error_handler'

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

    def bean_name
      raise 'Not Implemented'
    end

    def full_body(action:, body:, namespace:)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <?xml version="1.0" encoding="UTF-8"?>
          <env:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:tns="#{namespace}" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
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

    def parsed_response(res, action, key = nil)
      parsed = Hash.from_xml(res.body)
      if action == 'findIntentToFileByPtcpntIdItfTypeCd'
        itf_response = []
        [parsed.dig('Envelope', 'Body', "#{action}Response", key)].flatten.each do |itf|
          return itf_response if itf.nil?

          temp = itf.deep_transform_keys(&:underscore)
          &.deep_symbolize_keys
          itf_response.push(temp)
        end
        return itf_response
      end
      if key.nil?
        parsed.dig('Envelope', 'Body', "#{action}Response")
              &.deep_transform_keys(&:underscore)
              &.deep_symbolize_keys || {}
      else
        parsed.dig('Envelope', 'Body', "#{action}Response", key)
              &.deep_transform_keys(&:underscore)
              &.deep_symbolize_keys || {}
      end
    end

    def make_request(endpoint:, action:, body:, key: nil) # rubocop:disable Metrics/MethodLength
      connection = log_duration event: 'establish_ssl_connection' do
        Faraday::Connection.new(ssl: { verify_mode: @ssl_verify_mode })
      end
      connection.options.timeout = @timeout

      wsdl = log_duration(event: 'connection_wsdl_get', endpoint:) do
        connection.get("#{Settings.bgs.url}/#{endpoint}?WSDL")
      end
      target_namespace = Hash.from_xml(wsdl.body).dig('definitions', 'targetNamespace')
      response = log_duration(event: 'connection_post', endpoint:, action:) do
        connection.post("#{Settings.bgs.url}/#{endpoint}", full_body(action:,
                                                                     body:,
                                                                     namespace: target_namespace),
                        {
                          'Content-Type' => 'text/xml;charset=UTF-8',
                          'Host' => "#{@env}.vba.va.gov",
                          'Soapaction' => "\"#{action}\""
                        })
      end

      soap_error_handler.handle_errors(response) if response

      log_duration(event: 'parsed_response', key:) do
        parsed_response(response, action, key)
      end
    end

    def healthcheck(endpoint)
      connection = Faraday::Connection.new(ssl: { verify_mode: @ssl_verify_mode })
      wsdl = connection.get("#{Settings.bgs.url}/#{endpoint}?WSDL")
      wsdl.status
    end

    def find_poa_by_participant_id(id)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <ptcpntId />
      EOXML

      { ptcpntId: id }.each do |k, v|
        body.xpath("./*[local-name()='#{k}']")[0].content = v
      end

      make_request(endpoint: 'ClaimantServiceBean/ClaimantWebService', action: 'findPOAByPtcpntId', body:,
                   key: 'return')
    end

    def find_by_ssn(ssn)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <ssn />
      EOXML

      { ssn: }.each do |k, v|
        body.xpath("./*[local-name()='#{k}']")[0].content = v
      end

      make_request(endpoint: 'PersonWebServiceBean/PersonWebService', action: 'findPersonBySSN', body:,
                   key: 'PersonDTO')
    end

    def find_poa_history_by_ptcpnt_id(id)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <ptcpntId />
      EOXML

      { ptcpntId: id }.each do |k, v|
        body.xpath("./*[local-name()='#{k}']")[0].content = v
      end

      make_request(endpoint: 'OrgWebServiceBean/OrgWebService', action: 'findPoaHistoryByPtcpntId', body:,
                   key: 'PoaHistory')
    end

    def find_benefit_claims_status_by_ptcpnt_id(id)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <ptcpntId />
      EOXML

      { ptcpntId: id }.each do |k, v|
        body.xpath("./*[local-name()='#{k}']")[0].content = v
      end

      make_request(endpoint: 'EBenefitsBnftClaimStatusWebServiceBean/EBenefitsBnftClaimStatusWebService',
                   action: 'findBenefitClaimsStatusByPtcpntId', body:)
    end

    def find_benefit_claim_details_by_benefit_claim_id(id)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <bnftClaimId />
      EOXML

      { bnftClaimId: id }.each do |k, v|
        body.xpath("./*[local-name()='#{k}']")[0].content = v
      end

      make_request(endpoint: 'EBenefitsBnftClaimStatusWebServiceBean/EBenefitsBnftClaimStatusWebService',
                   action: 'findBenefitClaimDetailsByBnftClaimId', body:)
    end

    def insert_intent_to_file(options)
      request_body = construct_itf_body(options)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <intentToFileDTO>
        </intentToFileDTO>
      EOXML

      request_body.each do |k, z|
        node = Nokogiri::XML::Node.new k.to_s, body
        node.content = z.to_s
        opt = body.at('intentToFileDTO')
        node.parent = opt
      end
      make_request(endpoint: 'IntentToFileWebServiceBean/IntentToFileWebService', action: 'insertIntentToFile',
                   body:, key: 'IntentToFileDTO')
    end

    def find_tracked_items(id)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <claimId />
      EOXML

      { claimId: id }.each do |k, v|
        body.xpath("./*[local-name()='#{k}']")[0].content = v
      end

      make_request(endpoint: 'TrackedItemService/TrackedItemService', action: 'findTrackedItems', body:,
                   key: 'BenefitClaim')
    end

    def find_intent_to_file_by_ptcpnt_id_itf_type_cd(id, type)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <ptcpntId></ptcpntId><itfTypeCd></itfTypeCd>
      EOXML

      ptcpnt_id = body.at 'ptcpntId'
      ptcpnt_id.content = id.to_s
      itf_type_cd = body.at 'itfTypeCd'
      itf_type_cd.content = type.to_s

      make_request(endpoint: 'IntentToFileWebServiceBean/IntentToFileWebService',
                   action: 'findIntentToFileByPtcpntIdItfTypeCd', body:, key: 'IntentToFileDTO')
    end

    # BEGIN: switching v1 from evss to bgs. Delete after EVSS is no longer available. Fix controller first.
    def update_from_remote(id)
      bgs_claim = find_benefit_claim_details_by_benefit_claim_id(id)
      transform_bgs_claim_to_evss(bgs_claim)
    end

    def all(id)
      claims = find_benefit_claims_status_by_ptcpnt_id(id)
      transform_bgs_claims_to_evss(claims)
    end
    # END: switching v1 from evss to bgs. Delete after EVSS is no longer available. Fix controller first.

    private

    def construct_itf_body(options)
      request_body = {
        itfTypeCd: options[:intent_to_file_type_code],
        ptcpntVetId: options[:participant_vet_id],
        rcvdDt: options[:received_date],
        signtrInd: options[:signature_indicated],
        submtrApplcnTypeCd: options[:submitter_application_icn_type_code]
      }
      request_body[:ptcpntClmantId] = options[:participant_claimant_id] if options.key?(:participant_claimant_id)
      request_body[:clmantSsn] = options[:claimant_ssn] if options.key?(:claimant_ssn)
      request_body
    end

    def log_duration(event: 'default', **extra_params)
      # Who are we to question sidekiq's use of CLOCK_MONOTONIC to avoid negative durations?
      # https://github.com/sidekiq/sidekiq/issues/3999
      start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      result = yield
      duration = (::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - start_time).round(4)

      # event should be first key in log, duration last
      ClaimsApi::Logger.log 'local_bgs', **{ event: }.merge(extra_params).merge({ duration: })
      StatsD.measure("api.claims_api.local_bgs.#{event}.duration", duration, tags: {})
      result
    end

    def soap_error_handler
      ClaimsApi::SoapErrorHandler.new
    end

    def transform_bgs_claim_to_evss(claim)
      bgs_claim = ClaimsApi::EvssBgsMapper.new(claim[:benefit_claim_details_dto])
      bgs_claim.map_and_build_object
    end

    def transform_bgs_claims_to_evss(claims)
      claims[:benefit_claims_dto][:benefit_claim].map do |claim|
        bgs_claim = ClaimsApi::EvssBgsMapper.new(claim)
        bgs_claim.map_and_build_object
      end
    end

    def to_camelcase(claim:)
      claim.deep_transform_keys { |k| k.to_s.camelize(:lower) }
    end
  end
end
