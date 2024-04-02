# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/vnp_ptcpnt_addrs_service'

describe ClaimsApi::VnpPtcpntAddrsService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  describe 'vnp_ptcpnt_addrs_create' do
    let(:options) { {} }

    it 'responds with attributes' do
      options[:vnp_ptcpnt_addrs_id] = nil
      options[:vnp_proc_id] = '3854437'
      options[:vnp_ptcpnt_id] = nil
      options[:efctv_dt] = '2020-07-16T18:20:17Z'
      options[:addrs_one_txt] = ''
      options[:addrs_two_txt] = ''
      options[:addrs_three_txt] = ''
      options[:bad_addrs_ind] = nil
      options[:city_nm] = 'Bridgeport'
      options[:cntry_nm] = 'United States'
      options[:county_nm] = 'Fairfield'
      options[:eft_waiver_type_nm] = 281
      options[:email_addrs_txt] = 281
      options[:end_dt] = '2025-07-16T18:20:17Z'
      options[:fms_addrs_code_txt] = 281
      options[:frgn_postal_cd] = nil
      options[:group_1_verifd_type_cd] = nil
      options[:jrn_dt] = '2020-07-16T18:20:17Z'
      options[:jrn_lctn_id] = 281
      options[:jrn_obj_id] = 'VAgovAPI'
      options[:jrn_status_type_cd] = 'U'
      options[:jrn_user_id] = 'VAgovAPI'
      options[:lctn_nm] = nil
      options[:mlty_postal_type_cd] = nil
      options[:mlty_post_office_type_cd] = nil
      options[:postal_cd] = nil
      options[:prvnc_nm] = nil
      options[:ptcpnt_addrs_type_nm] = 'VAgovAPI'
      options[:shared_addrs_ind] = nil
      options[:trsury_addrs_six_txt] = nil
      options[:trsury_addrs_five_txt] = nil
      options[:trsury_addrs_four_txt] = nil
      options[:trsury_addrs_three_txt] = nil
      options[:trsury_addrs_two_txt] = nil
      options[:trsury_addrs_one_txt] = nil
      options[:trsury_seq_nbr] = nil
      options[:trtry_nm] = nil
      options[:zip_first_suffix_nbr] = 0
      options[:zip_prefix_nbr] = 64
      options[:zip_second_suffix_nbr] = 68

      VCR.use_cassette('bgs/vnp_ptcpnt_addrs_service/vnp_ptcpnt_addrs_create') do
        response = subject.vnp_ptcpnt_addrs_create(options)
        byebug
        expect(response).to include(
          { vnp_ptcpnt_id: '181913',
            vnp_proc_id: '3854437',
            jrn_dt: '2020-07-16T18:20:17Z',
            jrn_lctn_id: '281',
            jrn_obj_id: 'VAgovAPI',
            jrn_status_type_cd: 'U',
            jrn_user_id: 'VAgovAPI',
            ptcpnt_type_nm: 'Person' }
        )
      end
    end
  end
end
