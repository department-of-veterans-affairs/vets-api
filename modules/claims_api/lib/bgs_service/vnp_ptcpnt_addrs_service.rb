# frozen_string_literal: true

module ClaimsApi
  class VnpPtcpntAddrsService < ClaimsApi::LocalBGS
    FORM_TYPE_CD = '21-22'

    def vnp_ptcpnt_addrs_create(options)
      vnp_proc_id = options[:vnp_proc_id]
      options.delete(:vnp_proc_id)
      arg_strg = convert_nil_values(options)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <arg0>
          <compId>
            <vnpProcId>#{vnp_proc_id}</vnpProcId>
            <formTypeCd>#{FORM_TYPE_CD}</formTypeCd>
          </compId>
        #{arg_strg}
        </arg0>
      EOXML

      make_request(endpoint: 'VnpPtcpntAddrsWebServiceBean/VnpPtcpntAddrsService',
                   action: 'vnpPtcpntAddrsCreate', body:, key: 'return')
    end
  end
end
