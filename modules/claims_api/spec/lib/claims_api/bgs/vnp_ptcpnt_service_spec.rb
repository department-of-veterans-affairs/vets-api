# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/vnp_ptcpnt_service'

describe ClaimsApi::VnpPtcpntService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  describe 'vnp_ptcpnt_create' do
    let(:options) { {} }

    it 'responds with attributes' do
      options[:vnp_proc_id] = '3860232'
      options[:vnp_ptcpnt_id] = nil
      options[:fraud_ind] = nil
      options[:legacy_poa_cd] = nil
      options[:misc_vendor_ind] = nil
      options[:ptcpnt_short_nm] = nil
      options[:ptcpnt_type_nm] = 'Person'
      options[:tax_idfctn_nbr] = nil
      options[:tin_waiver_reason_type_cd] = nil
      options[:ptcpnt_fk_ptcpnt_id] = nil
      options[:corp_ptcpnt_id] = nil
      VCR.use_cassette('claims_api/bgs/vnp_ptcpnt_service/vnp_ptcpnt_create') do
        response = subject.vnp_ptcpnt_create(options)
        expect(response).to include(
          { vnp_ptcpnt_id: '189015',
            vnp_proc_id: '3860232',
            jrn_dt: '2020-07-16T18:20:17Z',
            jrn_lctn_id: '281',
            jrn_obj_id: 'VAgovAPI',
            jrn_status_type_cd: 'U',
            jrn_user_id: 'VAgovAPI',
            ptcpnt_type_nm: 'Person' }
        )
      end
    end

    it 'responds appropriately with an invalid options' do
      options[:vnp_proc_id] = 'not-an-id'
      options[:jrn_lctn_id] = 0
      options[:jrn_status_type_cd] = 'U'
      VCR.use_cassette('claims_api/bgs/vnp_ptcpnt_service/invalid_vnp_ptcpnt_create') do
        expect do
          subject.vnp_ptcpnt_create(options)
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end
  end
end
