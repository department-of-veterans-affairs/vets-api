# frozen_string_literal: true

module ClaimsApi
  class VnpPtcpntService < ClaimsApi::LocalBGS
    # vnpPtcpntCreate - This service is used to create VONAPP participant information
    def vnp_ptcpnt_create(options)
      convert_nil_values(options)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        # {arg_strg}
      EOXML

      make_request(endpoint: 'VnpPtcpntWebServiceBean/VnpPtcpntService', action: 'vnpPtcpntCreate', body:,
                   key: 'return')
    end

    private

    def convert_nil_values(options)
      arg_strg = '<arg0>'
      options.each do |option|
        arg = option[0].to_s.camelize(:lower)
        arg_strg += (option[1].nil? ? "<#{arg} xsi:nil=true/>" : "<#{arg}>#{option[1]}</#{arg}>")
      end
      arg_strg += '</arg0>'
    end
  end
end
