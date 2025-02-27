# frozen_string_literal: true

module ClaimsApi
  class VnpProcServiceV2 < ClaimsApi::LocalBGS
    PROC_TYPE_CD = 'POAAUTHZ'
    PROC_STATE = 'COMPLETE'

    def bean_name
      'VnpProcWebServiceBeanV2/VnpProcServiceV2'
    end

    def vnp_proc_create
      created_date = Time.current.iso8601
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <arg0>
          <VnpProcDTO>
            <vnpProcTypeCd>#{PROC_TYPE_CD}</vnpProcTypeCd>
            <vnpProcStateTypeCd>#{PROC_STATE}</vnpProcStateTypeCd>
            <creatdDt>#{Time.now}</creatdDt>
          </VnpProcDTO>
        </arg0>
      EOXML

      make_request(endpoint: 'VnpProcWebServiceBeanV2/VnpProcServiceV2', action: 'vnpProcCreate', body:, key: 'return')
    end
  end
end
