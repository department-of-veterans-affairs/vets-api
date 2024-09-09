# frozen_string_literal: true

module ClaimsApi
  class PersonWebService < ClaimsApi::LocalBGS
    def bean_name
      'PersonWebServiceBean/PersonWebService'
    end

    def find_dependents_by_ptcpnt_id(id)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <ptcpntId />
      EOXML

      { ptcpntId: id }.each do |k, v|
        body.xpath("./*[local-name()='#{k}']").first.content = v
      end

      make_request(endpoint: bean_name, action: 'findDependentsByPtcpntId', body:, key: 'DependentDTO')
    end
  end
end
