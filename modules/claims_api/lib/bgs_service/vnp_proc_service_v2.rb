# frozen_string_literal: true

module ClaimsApi
  class VnpProcServiceV2 < ClaimsApi::LocalBGS
    PROC_TYPE_CD = 'POAAUTHZ'
    PROC_STATE = 'Complete'

    def bean_name
      'VnpProcWebServiceBeanV2/VnpProcServiceV2'
    end

    def vnp_proc_create
      current_date = Time.current.iso8601
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <arg0>
          <vnpProcId>0</vnpProcId>
          <vnpProcTypeCd>#{PROC_TYPE_CD}</vnpProcTypeCd>
          <vnpProcStateTypeCd>#{PROC_STATE}</vnpProcStateTypeCd>
          <creatdDt>#{current_date}</creatdDt>
          <lastModifdDt>#{current_date}</lastModifdDt>
          <submtdDt>#{current_date}</submtdDt>
        </arg0>
      EOXML

      make_request(endpoint: 'VnpProcWebServiceBeanV2/VnpProcServiceV2', action: 'vnpProcCreate', body:, key: 'return')
    end
  end
end
