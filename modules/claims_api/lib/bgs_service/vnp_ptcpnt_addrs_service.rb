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

      make_request(endpoint: 'VnpPtcpntAddrsWebServiceBean/VnpPtcpntAddrsService',
                   action: 'vnpPtcpntAddrsCreate', body:, key: 'return')
    end
  end
end
