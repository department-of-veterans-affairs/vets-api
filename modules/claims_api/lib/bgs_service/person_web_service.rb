# frozen_string_literal: true

module ClaimsApi
  class PersonWebService < ClaimsApi::LocalBGS
    def bean_name
      'PersonWebServiceBean/PersonWebService'
    end

    def find_dependents_by_ptcpnt_id(id)
      builder = Nokogiri::XML::Builder.new do
        ptcpntId id
      end

      body = builder_to_xml(builder)

      make_request(endpoint: bean_name, action: 'findDependentsByPtcpntId', body:, key: 'DependentDTO')
    end

    # ptcpntIdA is the veteranʼs or dependentʼs participant id
    # ptcpntIdB is the poaʼs participant id
    def manage_ptcpnt_rlnshp_poa(**options)
      builder = Nokogiri::XML::Builder.new do
        PtcpntRlnshpDTO do
          authznChangeClmantAddrsInd 'Y' if options[:authzn_change_clmant_addrs_ind].present?
          authznPoaAccessInd options[:authzn_poa_access_ind].presence || 'N'
          compId do
            ptcpntIdA options[:ptcpnt_id_a]
            ptcpntIdB options[:ptcpnt_id_b]
          end
          statusTypeCd options[:status_type_cd] || 'CURR'
        end
      end

      body = builder_to_xml(builder)

      make_request(endpoint: bean_name, action: 'managePtcpntRlnshpPoa', body:, key: 'PtcpntRlnshpDTO')
    end

    # finds a PERSON row by SSN
    def find_by_ssn(ssn)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <ssn>#{ssn}</ssn>
      EOXML

      make_request(endpoint: bean_name, action: 'findPersonBySSN', body:, key: 'PersonDTO')
    end
  end
end
