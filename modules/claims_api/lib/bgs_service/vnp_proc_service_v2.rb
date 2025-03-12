# frozen_string_literal: true

module ClaimsApi
  class VnpProcServiceV2 < ClaimsApi::LocalBGS
    PROC_TYPE_CD = 'POAAUTHZ'

    def bean_name
      'VnpProcWebServiceBeanV2/VnpProcServiceV2'
    end

    def vnp_proc_create
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <arg0>
          <VnpProcDTO>
            <vnpProcTypeCd>#{PROC_TYPE_CD}</vnpProcTypeCd>
          </VnpProcDTO>
        </arg0>
      EOXML

      make_request(endpoint: 'VnpProcWebServiceBeanV2/VnpProcServiceV2', action: 'vnpProcCreate', body:, key: 'return')
    end
  end
end
