# frozen_string_literal: true

module ClaimsApi
  class OrgWebService < ClaimsApi::LocalBGS
    def bean_name
      'OrgWebServiceBean/OrgWebService'
    end

    def find_poa_history_by_ptcpnt_id(id)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <ptcpntId>#{id}</ptcpntId>
      EOXML

      make_request(endpoint: 'OrgWebServiceBean/OrgWebService', action: 'findPoaHistoryByPtcpntId', body:,
                   key: 'PoaHistory')
    end
  end
end
