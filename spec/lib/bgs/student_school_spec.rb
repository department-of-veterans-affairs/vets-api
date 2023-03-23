# frozen_string_literal: true

require 'rails_helper'
require 'bgs/student_school'

RSpec.describe BGS::StudentSchool do
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }
  let(:proc_id) { '3829729' }
  let(:vnp_participant_id) { '149471' }
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674_kitchen_sink) }
  let(:school_params) do
    {
      course_name_txt: 'Something amazing',
      curnt_hours_per_wk_num: 37,
      curnt_school_addrs_one_txt: '55 twenty ninth St',
      curnt_school_addrs_three_txt: 'No. 5',
      curnt_school_addrs_two_txt: 'Bldg 5',
      curnt_school_addrs_zip_nbr: '61201',
      curnt_school_city_nm: 'Rock Island',
      curnt_school_nm: 'My Great School',
      curnt_school_postal_cd: 'AR',
      curnt_sessns_per_wk_num: 4,
      vnp_proc_id: '3829729',
      vnp_ptcpnt_id: '149471',
      full_time_studnt_type_cd: 'HighSch',
      part_time_school_subjct_txt: 'An amazing program'
    }
  end
  let(:student_params) do
    {
      agency_paying_tuitn_nm: 'Some Agency',
      govt_paid_tuitn_ind: 'Y',
      next_year_annty_income_amt: '3989',
      next_year_emplmt_income_amt: '12000',
      next_year_other_income_amt: '984',
      next_year_ssa_income_amt: '3940',
      other_asset_amt: '4566',
      real_estate_amt: '5623',
      rmks: "Some remarks about the student's net worth",
      saving_amt: '3455',
      stock_bond_amt: '3234',
      term_year_annty_income_amt: '30595',
      term_year_emplmt_income_amt: '12000',
      term_year_other_income_amt: '5596',
      term_year_ssa_income_amt: '3453',
      vnp_proc_id: '3829729',
      vnp_ptcpnt_id: '149471'
    }
  end

  describe '#create' do
    it 'creates a child school and a child student' do
      VCR.use_cassette('bgs/student_school/create') do
        expect_any_instance_of(BGS::VnpChildSchoolService).to receive(:child_school_create).with(
          hash_including(school_params)
        )
        expect_any_instance_of(BGS::VnpChildStudentService).to receive(:child_student_create).with(
          hash_including(student_params)
        )

        BGS::StudentSchool.new(
          proc_id:,
          vnp_participant_id:,
          payload: all_flows_payload,
          user: user_object
        ).create
      end
    end
  end
end
