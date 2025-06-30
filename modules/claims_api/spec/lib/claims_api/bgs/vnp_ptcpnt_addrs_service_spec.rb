# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/vnp_ptcpnt_addrs_service'
require Rails.root.join('modules', 'claims_api', 'spec', 'support', 'bgs_client_spec_helpers.rb')

metadata = {
  bgs: {
    service: 'vnp_ptcpnt_addrs_service',
    action: 'vnp_ptcpnt_addrs_create'
  }
}

describe ClaimsApi::VnpPtcpntAddrsService, metadata do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  describe 'vnp_ptcpnt_addrs_create' do
    let(:options) { {} }

    it 'responds with attributes' do
      options[:vnp_ptcpnt_addrs_id] = nil
      options[:vnp_proc_id] = '3860232'
      options[:vnp_ptcpnt_id] = '189015'
      options[:efctv_dt] = '2020-07-16T18:20:18Z'
      options[:addrs_one_txt] = '76 Crowther Ave'
      options[:addrs_three_txt] = nil
      options[:addrs_two_txt] = nil
      options[:bad_addrs_ind] = nil
      options[:city_nm] = 'Bridgeport'
      options[:cntry_nm] = nil
      options[:county_nm] = nil
      options[:eft_waiver_type_nm] = nil
      options[:email_addrs_txt] = 'testy@test.com'
      options[:end_dt] = nil
      options[:fms_addrs_code_txt] = nil
      options[:frgn_postal_cd] = nil
      options[:group_1_verifd_type_cd] = nil
      options[:lctn_nm] = nil
      options[:mlty_postal_type_cd] = nil
      options[:mlty_post_office_type_cd] = nil
      options[:postal_cd] = 'CT'
      options[:prvnc_nm] = 'CT'
      options[:ptcpnt_addrs_type_nm] = 'Mailing'
      options[:shared_addrs_ind] = 'N'
      options[:trsury_addrs_five_txt] = nil
      options[:trsury_addrs_four_txt] = nil
      options[:trsury_addrs_one_txt] = nil
      options[:trsury_addrs_six_txt] = nil
      options[:trsury_addrs_three_txt] = nil
      options[:trsury_addrs_two_txt] = nil
      options[:trsury_seq_nbr] = nil
      options[:trtry_nm] = nil
      options[:zip_first_suffix_nbr] = nil
      options[:zip_prefix_nbr] = '06605'
      options[:zip_second_suffix_nbr] = nil

      VCR.use_cassette('claims_api/bgs/vnp_ptcpnt_addrs_service/vnp_ptcpnt_addrs_create') do
        response = subject.vnp_ptcpnt_addrs_create(options)
        expect(response).to include(
          { vnp_ptcpnt_addrs_id: '151270',
            efctv_dt: '2020-07-16T18:20:18Z',
            vnp_ptcpnt_id: '189015',
            vnp_proc_id: '3860232',
            addrs_one_txt: '76 Crowther Ave',
            city_nm: 'Bridgeport',
            postal_cd: 'CT',
            ptcpnt_addrs_type_nm: 'Mailing',
            shared_addrs_ind: 'N',
            zip_prefix_nbr: '06605' }
        )
      end
    end

    it 'responds appropriately with invalid options' do
      options[:vnp_ptcpnt_addrs_id] = nil
      options[:vnp_proc_id] = 'not-an-id'
      options[:vnp_ptcpnt_id] = 'not-an-id'
      options[:efctv_dt] = '2020-07-16T18:20:18Z'
      options[:addrs_one_txt] = '76-Crowther%Ave'
      VCR.use_cassette('claims_api/bgs/vnp_ptcpnt_addrs_service/invalid_vnp_ptcpnt_addrs_create') do
        expect do
          subject.vnp_ptcpnt_addrs_create(options)
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end
  end
end
