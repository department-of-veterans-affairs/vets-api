# frozen_string_literal: true

module ClaimsApi
  class VnpProcFormService < ClaimsApi::LocalBGS
    FORM_TYPE_CD = '21-22'

    def vnp_proc_form_create(options)
      vnp_proc_id = options[:vnp_proc_id]
      options.delete(:vnp_proc_id)
      vnp_proc_id = '<vnpProcId xis:nil=true/>' if vnp_proc_id.blank?
      arg_strg = convert_nil_values(options)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <arg0>
          <compId>
            <vnpProcId>#{vnp_proc_id}</vnpProcId>
            <formTypeCd>#{FORM_TYPE_CD}</formTypeCd>
          </compId>
        #{arg_strg}
      EOXML

      make_request(endpoint: 'VnpProcFormWebServiceBean/VnpProcFormService',
                   action: 'vnpProcFormCreate', body:, key: 'return')
    end

    private

    def convert_nil_values(options)
      arg_strg = ''
      options.each do |option|
        arg = option[0].to_s.camelize(:lower)
        arg_strg += (option[1].nil? ? "<#{arg} xsi:nil=true/>" : "<#{arg}>#{option[1]}</#{arg}>")
      end
      arg_strg += '</arg0>'
    end
  end
end
