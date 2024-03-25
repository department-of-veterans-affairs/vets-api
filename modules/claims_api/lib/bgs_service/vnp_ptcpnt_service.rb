# frozen_string_literal: true

module ClaimsApi
  class VnpPtcpntService < ClaimsApi::LocalBGS
    # vnpPtcpntCreate - This service is used to create VONAPP participant information
    def vnp_ptcpnt_create(options) # rubocop:disable Metrics/MethodLength
      # validate_required_keys(vnp_ptcpnt_create_required_keys, options, __method__.to_s)
      options[:ptcpnt_type_nm] = 'Person' if options[:ptcpnt_type_nm].nil?
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <arg0>
          <VnpProcDTO>
            <ptcpntTypeNm>#{options[:ptcpnt_type_nm]}</ptcpntTypeNm>
            <vnpPtcpntId>#{options[:vnp_ptcpnt_id]}</vnpPtcpntId>
            <vnpProcId>#{options[:vnp_proc_id]}</vnpProcId>
            <fraudInd>#{options[:fraud_ind]}</fraudInd>
            <jrnDt>#{options[:jrn_dt]}</jrnDt>
            <jrnLctnId>#{options[:vnp_ptcpnt_id]}</jrnLctnId>
            <jrnObjId>#{options[:jrn_obj_id]}</jrnObjId>
            <jrnStatusTypeCd>#{options[:jrn_status_type_cd]}</jrnStatusTypeCd>
            <jrnUserId>#{options[:jrn_user_id]}</jrnUserId>
            <legacyPoaCd>#{options[:legacy_poa_cd]}</legacyPoaCd>
            <miscVendorInd>#{options[:misc_vendor_ind]}</miscVendorInd>
            <ptcpntShortNm>#{options[:ptcpnt_short_nm]}</ptcpntShortNm>
            <taxIdfctnNbr>#{options[:tax_idfctn_nbr]}</taxIdfctnNbr>
            <tinWaiverReasonTypeCd>#{options[:tin_waiver_reason_type_cd]}</tinWaiverReasonTypeCd>
            <ptcpntFkPtcpntId>#{options[:ptcpnt_fk_ptcpnt_id]}</ptcpntFkPtcpntId>
            <corpPtcpntId>#{options[:corp_ptcpnt_id]}</corpPtcpntId>
          </VnpProcDTO>
        </arg0>
      EOXML

      make_request(endpoint: 'VnpPtcpntWebServiceBean/VnpPtcpntService', action: 'vnpPtcpntCreate', body:,
                   key: 'return')
    end
  end
end
