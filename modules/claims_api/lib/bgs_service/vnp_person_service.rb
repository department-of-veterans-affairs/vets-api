# frozen_string_literal: true

module ClaimsApi
  class VnpPersonService < ClaimsApi::LocalBGS
    # Takes an object with a minimum of (other fields are camelized and passed to BGS):
    # procId: BGS procID
    # ptcpntId: Veteran's participant id
    # firstNm: Veteran's first name
    # lastNm: Veteran's last name
    def vnp_person_create(opts)
      opts = opts.dup
      opts.transform_keys! { |k| k.to_s.camelize(:lower) }

      validate_opts! opts, %w[vnpProcId vnpPtcpntId firstNm lastNm]

      opts = jrn.merge(opts)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <arg0></arg0>
      EOXML

      opts.each do |k, v|
        node = Nokogiri::XML::Node.new k.to_s, body
        node.content = v.to_s
        node.set_attribute('xsi:nil', 'true') if v.blank?
        opt = body.at('arg0')
        node.parent = opt
      end

      make_request(endpoint: 'VnpPersonWebServiceBean/VnpPersonService', action: 'vnpPersonCreate', body:,
                   key: 'return')
    end
  end
end
