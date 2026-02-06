# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::ChildSchool do
  let(:all_flows_payload_v2) { build(:form686c_674_v2) }
  let(:child_school_info_v2) do
    described_class.new('3829729',
                        '149471',
                        all_flows_payload_v2['dependents_application']['student_information'][0])
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

  describe '#params for 686c' do
    it 'formats child school params for submission' do
      formatted_info = child_school_info_v2.params_for_686c

      expect(formatted_info).to include(formatted_params_result_v2)
    end
  end
end
