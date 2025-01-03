# frozen_string_literal: true

module ClaimsApi
  class OrgWebService < ClaimsApi::LocalBGS
    def bean_name
      'OrgWebServiceBean/OrgWebService'
    end

    def find_poa_history_by_ptcpnt_id(id)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <ptcpntId />
      EOXML

      { ptcpntId: id }.each do |k, v|
        body.xpath("./*[local-name()='#{k}']")[0].content = v
      end

      make_request(endpoint: bean_name, action: 'findPoaHistoryByPtcpntId', body:,
                   key: 'PoaHistory')
    end
  end
end
