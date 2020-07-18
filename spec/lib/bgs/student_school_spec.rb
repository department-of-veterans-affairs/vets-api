# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::StudentSchool do
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }
  let(:user_hash) do
    {
      participant_id: user_object.participant_id,
      ssn: user_object.ssn,
      first_name: user_object.first_name,
      last_name: user_object.last_name,
      external_key: user_object.common_name || user_object.email,
      icn: user_object.icn
    }
  end
  let(:proc_id) { '3829729' }
  let(:vnp_participant_id) { '149471' }
  let(:fixtures_path) { Rails.root.join('spec', 'fixtures', '686c', 'dependents') }
  let(:all_flows_payload) do
    payload = File.read("#{fixtures_path}/all_flows_payload.json")
    JSON.parse(payload)
  end
  let(:child_response) do
    {
      vnp_child_school_id: '22941',
      course_name_txt: 'An amazing program',
      curnt_hours_per_wk_num: '37',
      curnt_school_addrs_one_txt: '2037 29th St',
      curnt_school_addrs_zip_nbr: '61201',
      curnt_school_nm: 'My Great School',
      curnt_school_postal_cd: 'AR'
    }
  end
  let(:school_response) do
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
      term_year_ssa_income_amt: '3453'
    }
  end

  describe '#create' do
    it 'creates a child school and a child student' do
      VCR.use_cassette('bgs/student_school/create') do
        student_school = BGS::StudentSchool.new(
          proc_id: proc_id,
          vnp_participant_id: vnp_participant_id,
          payload: all_flows_payload,
          user: user_hash
        ).create

        expect(student_school).to match(
          [
            a_hash_including(child_response),
            a_hash_including(school_response)
          ]
        )
      end
    end
  end
end
