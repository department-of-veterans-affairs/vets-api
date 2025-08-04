# frozen_string_literal: true

module ClaimsApi
  class VnpPtcpntAddrsService < ClaimsApi::LocalBGS
    def bean_name
      'VnpPtcpntAddrsWebServiceBean/VnpPtcpntAddrsService'
    end

    def vnp_ptcpnt_addrs_create(options)
      arg_strg = convert_nil_values(options)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <arg0>
        #{arg_strg}
        </arg0>
      EOXML

      make_request(endpoint: bean_name, action: 'vnpPtcpntAddrsCreate', body:, key: 'return')
    end

    def vnp_ptcpnt_addrs_find_by_primary_key(id:)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <vnpPtcpntAddrsId>#{id}</vnpPtcpntAddrsId>
      EOXML

      make_request(endpoint: bean_name, action: 'vnpPtcpntAddrsFindByPrimaryKey', body:, key: 'return')
    end
  end
end
