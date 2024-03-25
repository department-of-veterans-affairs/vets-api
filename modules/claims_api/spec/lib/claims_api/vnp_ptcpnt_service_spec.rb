# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/vnp_ptcpnt_service'

describe ClaimsApi::VnpPtcpntService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  describe 'vnp_ptcpnt_service' do
    let(:options) { {} }

    it 'responds with attributes' do
      options[:vnp_proc_id] = '3830249' # '3830252' # '3854437'
      #   options[:vnp_ptcpnt_id] = nil
      #   options[:fraud_ind] = nil
      #   options[:jrn_dt] = nil
      #   options[:jrn_lctn_id] = nil
      #   options[:jrn_obj_id] = nil
      #   options[:jrn_status_type_cd] = nil
      #   options[:jrn_user_id] = nil
      #   options[:legacy_poa_cd] = nil
      #   options[:misc_vendor_ind] = nil
      #   options[:ptcpnt_short_nm] = nil
      #   options[:ptcpnt_type_nm] = nil
      #   options[:tax_idfctn_nbr] = nil
      #   options[:tin_waiver_reason_type_cd] = nil
      #   options[:ptcpnt_fk_ptcpnt_id] = nil
      #   options[:corp_ptcpnt_id] = nil
      VCR.use_cassette('bgs/vnp_proc_service_v2/vnp_ptcpnt_service') do
        response = subject.vnp_ptcpnt_create(options)
        expect(response).to include(
          {
            vnp_bnft_claim_id: '426090',
            atchms_ind: 'N',
            bnft_claim_type_cd: '130DPNEBNADJ',
            ptcpnt_clmant_id: '150191',
            ptcpnt_mail_addrs_id: '116942',
            vnp_ptcpnt_vet_id: '150191',
            vnp_proc_id: '29637'
          }
        )
      end
    end
  end
end
