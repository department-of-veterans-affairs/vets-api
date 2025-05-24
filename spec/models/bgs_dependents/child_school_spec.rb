# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::ChildSchool do
  let(:all_flows_payload) { build(:form_686c_674_kitchen_sink) }
  let(:all_flows_payload_v2) { build(:form686c_674_v2) }
  let(:child_school_info) do
    described_class.new(all_flows_payload['dependents_application'], '3829729', '149471', is_v2: false)
  end
  let(:child_school_info_v2) do
    described_class.new(all_flows_payload_v2['dependents_application'],
                        '3829729',
                        '149471',
                        all_flows_payload_v2['dependents_application']['student_information'][0],
                        is_v2: true)
  end
  let(:formatted_params_result) do
    {
      vnp_proc_id: '3829729',
      vnp_ptcpnt_id: '149471',
      last_term_start_dt: DateTime.parse('2016-03-04 12:00:00').to_time.iso8601,
      last_term_end_dt: DateTime.parse('2017-04-05 12:00:00').to_time.iso8601,
      prev_hours_per_wk_num: 40,
      prev_sessns_per_wk_num: 4,
      prev_school_nm: 'Another Amazing School',
      prev_school_cntry_nm: 'USA',
      prev_school_addrs_one_txt: '20374 twenty ninth St',
      prev_school_city_nm: 'Rock Island',
      prev_school_postal_cd: 'IL',
      prev_school_addrs_zip_nbr: '61201',
      curnt_school_nm: 'My Great School',
      curnt_school_addrs_one_txt: '55 twenty ninth St',
      curnt_school_postal_cd: 'AR',
      curnt_school_city_nm: 'Rock Island',
      curnt_school_addrs_zip_nbr: '61201',
      curnt_school_cntry_nm: 'USA',
      course_name_txt: 'Something amazing',
      curnt_sessns_per_wk_num: 4,
      curnt_hours_per_wk_num: 37,
      school_actual_expctd_start_dt: '2019-03-03',
      school_term_start_dt: DateTime.parse('2019-03-05 12:00:00').to_time.iso8601,
      gradtn_dt: DateTime.parse('2023-03-03 12:00:00').to_time.iso8601,
      full_time_studnt_type_cd: 'HighSch',
      part_time_school_subjct_txt: 'An amazing program'
    }
  end
  let(:formatted_params_result_v2) do
    {
      vnp_proc_id: '3829729',
      vnp_ptcpnt_id: '149471',
      last_term_start_dt: DateTime.parse('2024-01-01 12:00:00').to_time.iso8601,
      last_term_end_dt: DateTime.parse('2024-03-05 12:00:00').to_time.iso8601,
      prev_hours_per_wk_num: nil,
      prev_sessns_per_wk_num: nil,
      prev_school_nm: nil,
      prev_school_cntry_nm: nil,
      prev_school_addrs_one_txt: nil,
      prev_school_city_nm: nil,
      prev_school_postal_cd: nil,
      prev_school_addrs_zip_nbr: nil,
      curnt_school_nm: 'name of trade program',
      curnt_school_addrs_one_txt: nil,
      curnt_school_postal_cd: nil,
      curnt_school_city_nm: nil,
      curnt_school_addrs_zip_nbr: nil,
      curnt_school_cntry_nm: nil,
      course_name_txt: nil,
      curnt_sessns_per_wk_num: nil,
      curnt_hours_per_wk_num: nil,
      school_actual_expctd_start_dt: '2025-01-02',
      school_term_start_dt: DateTime.parse('2025-01-01 12:00:00').to_time.iso8601,
      gradtn_dt: DateTime.parse('2026-03-01 12:00:00').to_time.iso8601,
      full_time_studnt_type_cd: nil,
      part_time_school_subjct_txt: nil
    }
  end

  context 'with va_dependents_v2 off' do
    before do
      allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(false)
    end

    describe '#params for 686c' do
      it 'formats child school params for submission' do
        formatted_info = child_school_info.params_for_686c

        expect(formatted_info).to include(formatted_params_result)
      end
    end
  end

  context 'with va_dependents_v2 on' do
    before do
      allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(true)
    end

    describe '#params for 686c' do
      it 'formats child school params for submission' do
        formatted_info = child_school_info_v2.params_for_686c_v2

        expect(formatted_info).to include(formatted_params_result_v2)
      end
    end
  end
end
