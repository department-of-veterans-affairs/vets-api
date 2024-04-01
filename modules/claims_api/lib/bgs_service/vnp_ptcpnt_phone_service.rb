# frozen_string_literal: true

module ClaimsApi
  class VnpPtcpntPhoneService < ClaimsApi::LocalBGS
    # vnpPtcpntPhoneCreate - This service is used to create VONAPP participant phone information
    DEFAULT_TYPE = 'Daytime' # Daytime and Nighttime are the allowed values

    def vnp_ptcpnt_phone_create(options)
      request_body = construct_body(options)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <arg0>
        </arg0>
      EOXML

      request_body.each do |k, z|
        node = Nokogiri::XML::Node.new k.to_s, body
        node.content = z.to_s
        opt = body.at('arg0')
        node.parent = opt
      end

      make_request(endpoint: 'VnpPtcpntPhoneWebServiceBean/VnpPtcpntPhoneService', action: 'vnpPtcpntPhoneCreate',
                   body:, key: 'return')
    end

    private

    def construct_body(options)
      {
        vnpProcId: options[:vnp_proc_id],
        vnpPtcpntId: options[:vnp_ptcpnt_id],
        phoneTypeNm: options[:phone_type_nm] || DEFAULT_TYPE,
        phoneNbr: options[:phone_nbr],
        efctvDt: options[:efctv_dt] || Time.current.iso8601
      }
    end
  end
end
