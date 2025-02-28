# frozen_string_literal: true

module ClaimsApi
  class VnpProcServiceV2 < ClaimsApi::LocalBGS
    PROC_TYPE_CD = 'POAAUTHZ'
    PROC_STATE = 'complete'

    def bean_name
      'VnpProcWebServiceBeanV2/VnpProcServiceV2'
    end

    def vnp_proc_create
      byebug
      # created_date = Date.new()
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <arg0>
          <VnpProcDTO>
            <vnpProcId>0</vnpProcId>
            <vnpProcTypeCd>#{PROC_TYPE_CD}</vnpProcTypeCd>
            <vnpProcStateTypeCd>#{PROC_STATE}</vnpProcStateTypeCd>
            <creatdDt>2025-02-28T14:19:18.637-05:00</creatdDt>
            <lastModifdDt>2025-02-28T14:19:18.637-05:00</lastModifdDt>
            <submtdDt>2025-02-28T14:19:18.637-05:00</submtdDt>
          </VnpProcDTO>
        </arg0>
      EOXML

      make_request(endpoint: 'VnpProcWebServiceBeanV2/VnpProcServiceV2', action: 'vnpProcCreate', body:, key: 'return')
    end
  end
end
