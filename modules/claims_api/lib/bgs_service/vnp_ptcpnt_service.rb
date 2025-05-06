# frozen_string_literal: true

module ClaimsApi
  class VnpPtcpntService < ClaimsApi::LocalBGS
    # vnpPtcpntCreate - This service is used to create VONAPP participant information
    #
    def bean_name
      'VnpPtcpntWebServiceBean/VnpPtcpntService'
    end

    def vnp_ptcpnt_create(options)
      arg_strg = convert_nil_values(options)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <arg0>
          #{arg_strg}
          </arg0>
      EOXML

      make_request(endpoint: 'VnpPtcpntWebServiceBean/VnpPtcpntService', action: 'vnpPtcpntCreate', body:,
                   key: 'return')
    end
  end
end
