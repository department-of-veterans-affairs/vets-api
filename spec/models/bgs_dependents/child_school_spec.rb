# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::ChildSchool do
  let(:all_flows_payload) { FactoryBot.build(:form_686c_674) }
  let(:child_school_info) do
    described_class.new(all_flows_payload['dependents_application'], '3829729', '149471')
  end
  let(:formatted_params_result) do
    {
      vnp_proc_id: '3829729',
      vnp_ptcpnt_id: '149471',
      last_term_start_dt: Date.parse('2016-03-04').to_time.iso8601,
      last_term_end_dt: Date.parse('2017-04-05').to_time.iso8601,
      prev_hours_per_wk_num: 40,
      prev_sessns_per_wk_num: 4,
      prev_school_nm: 'Another Amazing School',
      prev_school_cntry_nm: 'USA',
      prev_school_addrs_one_txt: '2037 29th St',
      prev_school_city_nm: 'Rock Island',
      prev_school_postal_cd: 'IL',
      prev_school_addrs_zip_nbr: '61201',
      curnt_school_nm: 'My Great School',
      curnt_school_addrs_one_txt: '2037 29th St',
      curnt_school_postal_cd: 'AR',
      curnt_school_city_nm: 'Rock Island',
      curnt_school_addrs_zip_nbr: '61201',
      curnt_school_cntry_nm: 'USA',
      course_name_txt: 'An amazing program',
      curnt_sessns_per_wk_num: 4,
      curnt_hours_per_wk_num: 37,
      school_actual_expctd_start_dt: '2019-03-03',
      school_term_start_dt: Date.parse('2019-03-05').to_time.iso8601,
      gradtn_dt: Date.parse('2023-03-03').to_time.iso8601
    }
  end

  describe '#params for 686c' do
    it 'formats child school params for submission' do
      formatted_info = child_school_info.params_for_686c

      expect(formatted_info).to include(formatted_params_result)
    end
  end
end
