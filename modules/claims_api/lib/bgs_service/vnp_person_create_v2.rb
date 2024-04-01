# frozen_string_literal: true

module ClaimsApi
  class VnpPersonCreateV2 < ClaimsApi::LocalBGS
    # Takes an object with a minimum of (other fields are camelized and passed to BGS):
    # procId: BGS procID
    # ptcpntId: Veteran's participant id
    # firstNm: Veteran's first name
    # lastNm: Veteran's last name
    #
    # The target veteran can be passed in as an optional second argument
    # this overrides the ptcpntId, firstNm, and lastNm fields in the opts.
    #
    # The icn can be passed in as an optional third argument
    # this does an MPI lookup to override the ptcpntId, firstNm, and lastNm fields in the opts.
    def vnp_person_create(opts, target_veteran: nil, icn: nil)
      opts = opts.dup
      opts.merge!(icn_opts(icn)) if icn
      opts.merge!(target_veteran_opts(target_veteran)) if target_veteran
      opts.transform_keys! { |k| k.to_s.camelize(:lower) }

      validate_opts! opts

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

    private

    def jrn
      {
        jrnDt: Time.current.iso8601,
        jrnLctnId: Settings.bgs.client_station_id,
        jrnStatusTypeCd: 'U',
        jrnUserId: Settings.bgs.client_username,
        jrnObjId: Settings.bgs.application
      }
    end

    def validate_opts!(opts)
      required_keys = %w[vnpProcId vnpPtcpntId firstNm lastNm]
      missing_keys = required_keys.reject { opts.key? _1 }
      raise ArgumentError, "Missing required keys: #{missing_keys.join(', ')}" if missing_keys.present?
    end

    def target_veteran_opts(target_veteran)
      {
        vnpPtcpntId: target_veteran.participant_id,
        firstNm: target_veteran.first_name,
        lastNm: target_veteran.last_name
      }
    end

    def icn_opts(icn)
      mpi_profile = MPI::Service.new.find_profile_by_identifier(identifier: icn,
                                                                identifier_type: MPI::Constants::ICN)
      {
        vnpPtcpntId: mpi_profile.profile.participant_id,
        firstNm: mpi_profile.profile.given_names.first,
        lastNm: mpi_profile.profile.family_name
      }
    end
  end
end
