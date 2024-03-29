# frozen_string_literal: true

module ClaimsApi
  class VnpPersonCreateV2 < ClaimsApi::LocalBGS
    def vnp_person_create(proc_id, target_veteran)
      opts = build_opts(proc_id, target_veteran)

      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <arg0></arg0>
      EOXML

      opts.each do |k, v|
        node = Nokogiri::XML::Node.new k.to_s.camelize(:lower), body
        node.content = v.to_s
        node.set_attribute('xsi:nil', 'true')
        opt = body.at('arg0')
        node.parent = opt
      end

      res = make_request(endpoint: 'VnpPersonWebServiceBean/VnpPersonService', action: 'vnpPersonCreate', body:,
                   key: 'return')
      return res
    end

    private

    def build_opts(proc_id, target_veteran)
      {
        vnpProcId: proc_id,
        procId: proc_id,
        vnpPtcpntId: target_veteran.participant_id,
        ptcpntId: target_veteran.participant_id,
        jrnDt: Time.current.iso8601,
        jrnLctnId: Settings.bgs.client_station_id,
        jrnStatusTypeCd: 'U',
        jrnUserId: Settings.bgs.client_username,
        jrnObjId: Settings.bgs.application,
        firstNm: target_veteran.first_name,
        lastNm: target_veteran.last_name
      }
    end
  end
end
