# frozen_string_literal: true

module ClaimsApi
  class IntentToFileWebService < ClaimsApi::LocalBGS
    def bean_name
      'IntentToFileWebServiceBean/IntentToFileWebService'
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
  end
end
