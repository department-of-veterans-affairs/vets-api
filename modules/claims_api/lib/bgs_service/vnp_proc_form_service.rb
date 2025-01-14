# frozen_string_literal: true

module ClaimsApi
  class VnpProcFormService < ClaimsApi::LocalBGS
    FORM_TYPE_CD = '21-22'

    def bean_name
      'VnpProcFormWebServiceBean/VnpProcFormService'
    end

    def vnp_proc_form_create(options)
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

      make_request(endpoint: 'VnpProcFormWebServiceBean/VnpProcFormService',
                   action: 'vnpProcFormCreate', body:, key: 'return')
    end
  end
end
