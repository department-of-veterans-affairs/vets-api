# frozen_string_literal: true

module ClaimsApi
  class VnpProcFormService < LocalBGS
    FORM_TYPE_CD = '21-22'

    def vnp_proc_form_create(options)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <arg0>
          <VnpProcFormDTO>
            <compId>
               <vnpProcId>#{options[:vnp_proc_id]}</vnpProcId>
               <formTypeCd>#{FORM_TYPE_CD}</formTypeCd>
            </compId>
            <jrnDt>#{options[:jrn_dt]}</jrnDt>
            <jrnLctnId>#{options[:vnp_ptcpnt_id]}</jrnLctnId>
            <jrnObjId>#{options[:jrn_obj_id]}</jrnObjId>
            <jrnStatusTypeCd>#{options[:jrn_status_type_cd]}</jrnStatusTypeCd>
            <jrnUserId>#{options[:jrn_user_id]}</jrnUserId>
          </VnpProcFormDTO>
        </arg0>
      EOXML

      make_request(endpoint: 'VnpProcFormWebServiceBean/VnpProcFormService',
                   action: 'vnpProcFormCreate', body:, key: 'return')
    end
  end
end