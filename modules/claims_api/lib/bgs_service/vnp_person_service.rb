# frozen_string_literal: true

module ClaimsApi
  class VnpPersonService < ClaimsApi::LocalBGS
    def bean_name
      'VnpPersonWebServiceBean/VnpPersonService'
    end

    # Takes an object with a minimum of (other fields are camelized and passed to BGS):
    # vnp_proc_id: BGS procID
    # vnp_ptcpnt_id: Veteran's participant id
    # first_nm: Veteran's first name
    # last_nm: Veteran's last name
    def vnp_person_create(opts)
      validate_opts! opts, %w[vnp_proc_id vnp_ptcpnt_id first_nm last_nm]
      arg_strg = convert_nil_values(opts)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <arg0>#{arg_strg}</arg0>
      EOXML

      make_request(endpoint: 'VnpPersonWebServiceBean/VnpPersonService', action: 'vnpPersonCreate', body:,
                   key: 'return')
    end
  end
end
