# frozen_string_literal: true

module ClaimsApi
  class CorporateUpdateWebService < ClaimsApi::LocalBGS
    def bean_name
      'CorporateUpdateServiceBean/CorporateUpdateWebService'
    end

    def update_poa_access(participant_id:, poa_code:, allow_poa_access: 'Y', allow_poa_c_add: 'Y')
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <ptcpntId>#{participant_id}</ptcpntId>
        <poa>#{poa_code}</poa>
        <allowPoaAccess>#{allow_poa_access}</allowPoaAccess>
        <allowPoaCadd>#{allow_poa_c_add}</allowPoaCadd>
      EOXML

      response = make_request(endpoint: bean_name, action: 'updatePoaAccess', body:)
      response[:return]
    end
  end
end
