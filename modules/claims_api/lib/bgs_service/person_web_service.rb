# frozen_string_literal: true

module ClaimsApi
  class PersonWebService < ClaimsApi::LocalBGS
    def bean_name
      'PersonWebServiceBean/PersonWebService'
    end

    def find_dependents_by_ptcpnt_id(id)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <ptcpntId>#{id}</ptcpntId>
      EOXML

      make_request(endpoint: bean_name, action: 'findDependentsByPtcpntId', body:, key: 'DependentDTO')
    end

    # ptcpntIdA is the veteranʼs or dependentʼs participant id
    # ptcpntIdB is the poaʼs participant id
    def manage_ptcpnt_rlnshp_poa(options = {})
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <PtcpntRlnshpDTO>
          #{if options[:authzn_change_clmant_addrs_ind].present?
              '<authznChangeClmantAddrsInd>Y</authznChangeClmantAddrsInd>'
            end}
          #{'<authznPoaAccessInd>Y</authznPoaAccessInd>' if options[:authzn_poa_access_ind].present?}
          <compId>
            <ptcpntIdA>#{options[:ptcpnt_id_a]}</ptcpntIdA>
            <ptcpntIdB>#{options[:ptcpnt_id_b]}</ptcpntIdB>
          </compId>
          <statusTypeCd>#{options[:status_type_cd] || 'CURR'}</statusTypeCd>
        </PtcpntRlnshpDTO>
      EOXML

      make_request(endpoint: bean_name, action: 'managePtcpntRlnshpPoa', body:, key: 'DependentDTO')
    end
  end
end
