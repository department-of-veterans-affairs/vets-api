# frozen_string_literal: true

# As a work of the United States Government, this project is in the
# public domain within the United States.
#
# Additionally, we waive copyright and related rights in the work
# worldwide through the CC0 1.0 Universal public domain dedication.

require 'claims_api/claim_logger'
require 'claims_api/error/soap_error_handler'
require 'claims_api/evss_bgs_mapper'
require 'bgs_service/local_bgs_refactored'

module ClaimsApi
  class LocalBGS
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

    def claims_count(id)
      find_benefit_claims_status_by_ptcpnt_id(id).count
    rescue ::Common::Exceptions::ResourceNotFound
      0
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

      response =
        make_request(
          endpoint: 'IntentToFileWebServiceBean/IntentToFileWebService',
          action: 'findIntentToFileByPtcpntIdItfTypeCd',
          body:
        )

      Array.wrap(response[:intent_to_file_dto])
    end

    # BEGIN: switching v1 from evss to bgs. Delete after EVSS is no longer available. Fix controller first.
    def update_from_remote(id)
      bgs_claim = find_benefit_claim_details_by_benefit_claim_id(id)
      transform_bgs_claim_to_evss(bgs_claim)
    end

    def all(id)
      claims = find_benefit_claims_status_by_ptcpnt_id(id)
      return [] if claims.count < 1 || claims[:benefit_claims_dto].blank?

      transform_bgs_claims_to_evss(claims)
    end
    # END: switching v1 from evss to bgs. Delete after EVSS is no longer available. Fix controller first.

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
        url = "#{Settings.bgs.url}/#{endpoint}"
        body = full_body(action:, body:, namespace: namespace(connection, endpoint), namespaces:)
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
      byebug
      soap_error_handler.handle_errors(response) if response

      log_duration(event: 'parsed_response', key:) do
        parsed_response = parse_response(response, action:, key:)
        transform_response ? transform_keys(parsed_response) : parsed_response
      end
    end

    def namespace(connection, endpoint)
      ClaimsApi::LocalBGSRefactored::FindDefinition
        .for_service(endpoint)
        .bean.namespaces.target
    rescue => e
      unless e.is_a? ClaimsApi::LocalBGSRefactored::FindDefinition::NotDefinedError
        ClaimsApi::Logger.log('local_bgs', level: :error,
                                           detail: "local BGS FindDefinition Error: #{e.message}")
      end

      fetch_namespace(connection, endpoint)
    end

    def fetch_namespace(connection, endpoint)
      wsdl = log_duration(event: 'connection_wsdl_get', endpoint:) do
        connection.get("#{Settings.bgs.url}/#{endpoint}?WSDL")
      end
      Hash.from_xml(wsdl.body).dig('definitions', 'targetNamespace').to_s
    end

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
      event_for_log = { event: }.merge(extra_params).merge({ duration: })
      ClaimsApi::Logger.log 'local_bgs', **event_for_log
      StatsD.measure("api.claims_api.local_bgs.#{event}.duration", duration, tags: {})
      result
    end

    def soap_error_handler
      ClaimsApi::SoapErrorHandler.new
    end

    def transform_bgs_claim_to_evss(claim)
      bgs_claim = ClaimsApi::EvssBgsMapper.new(claim[:benefit_claim_details_dto])
      return if bgs_claim.nil?

      bgs_claim.map_and_build_object
    end

    def transform_bgs_claims_to_evss(claims)
      claims_array = [claims[:benefit_claims_dto][:benefit_claim]].flatten
      claims_array&.map do |claim|
        bgs_claim = ClaimsApi::EvssBgsMapper.new(claim)
        bgs_claim.map_and_build_object
      end
    end

    def to_camelcase(claim:)
      claim.deep_transform_keys { |k| k.to_s.camelize(:lower) }
    end

    def convert_nil_values(options)
      arg_strg = ''
      options.each do |option|
        arg = option[0].to_s.camelize(:lower)
        arg_strg += (option[1].nil? ? "<#{arg} xsi:nil='true'/>" : "<#{arg}>#{option[1]}</#{arg}>")
      end
      arg_strg
    end

    def validate_opts!(opts, required_keys)
      keys = opts.keys.map(&:to_s)
      required_keys = required_keys.map(&:to_s)
      missing_keys = required_keys - keys
      raise ArgumentError, "Missing required keys: #{missing_keys.join(', ')}" if missing_keys.present?
    end

    def jrn
      {
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_status_type_cd: 'U',
        jrn_user_id: Settings.bgs.client_username,
        jrn_obj_id: Settings.bgs.application
      }
    end

    private

    def builder_to_xml(builder)
      builder.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION)
    end

    def transform_keys(hash_or_array)
      transformer = lambda do |object|
        case object
        when Hash
          object.deep_transform_keys! { |k| k.underscore.to_sym }
        when Array
          object.map { |item| transformer.call(item) }
        else
          object
        end
      end

      transformer.call(hash_or_array)
    end

    def parse_response(response, action:, key:)
      keys = ['Envelope', 'Body', "#{action}Response"]
      keys << key if key.present?

      result = Hash.from_xml(response.body).dig(*keys)

      result.is_a?(Array) ? result : result.to_h
    end
  end
end
