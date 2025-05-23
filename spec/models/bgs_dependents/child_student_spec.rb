# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::ChildStudent do
  let(:all_flows_payload) { build(:form_686c_674_kitchen_sink) }
  let(:all_flows_payload_v2) { build(:form686c_674_v2) }
  let(:child_student_info) do
    described_class.new(all_flows_payload['dependents_application'], '3829729', '149471', false)
  end
  let(:child_student_info_v2) do
    described_class.new(all_flows_payload['dependents_application'],
                        '3829729',
                        '149471',
                        all_flows_payload_v2['dependents_application']['student_information'][0], true)
  end
  let(:formatted_params_result) do
    {
      vnp_proc_id: '3829729',
      vnp_ptcpnt_id: '149471',
      saving_amt: '3455',
      real_estate_amt: '5623',
      other_asset_amt: '4566',
      rmks: 'Some remarks about the student\'s net worth',
      marage_dt: DateTime.parse('2015-03-04 12:00:00').to_time.iso8601,
      agency_paying_tuitn_nm: 'Some Agency',
      stock_bond_amt: '3234',
      govt_paid_tuitn_ind: 'Y',
      govt_paid_tuitn_start_dt: DateTime.parse('2019-02-03 12:00:00').to_time.iso8601,
      term_year_emplmt_income_amt: '12000',
      term_year_other_income_amt: '5596',
      term_year_ssa_income_amt: '3453',
      term_year_annty_income_amt: '30595',
      next_year_annty_income_amt: '3989',
      next_year_emplmt_income_amt: '12000',
      next_year_other_income_amt: '984',
      next_year_ssa_income_amt: '3940',
      acrdtdSchoolInd: 'Y',
      atndedSchoolCntnusInd: 'N',
      stopedAtndngSchoolDt: nil
    }
  end
  let(:formatted_params_result_v2) do
    {
      vnp_proc_id: '3829729',
      vnp_ptcpnt_id: '149471',
      saving_amt: '500',
      real_estate_amt: '300',
      other_asset_amt: '200',
      rmks: 'test additional information',
      marage_dt: DateTime.parse('2024-03-03 12:00:00').to_time.iso8601,
      agency_paying_tuitn_nm: nil,
      stock_bond_amt: '400',
      govt_paid_tuitn_ind: 'Y',
      govt_paid_tuitn_start_dt: DateTime.parse('2024-03-01 12:00:00').to_time.iso8601,
      term_year_emplmt_income_amt: '56000',
      term_year_other_income_amt: '20',
      term_year_ssa_income_amt: '0',
      term_year_annty_income_amt: '123',
      next_year_annty_income_amt: '145',
      next_year_emplmt_income_amt: '56000',
      next_year_other_income_amt: '50',
      next_year_ssa_income_amt: '0',
      acrdtdSchoolInd: 'Y',
      atndedSchoolCntnusInd: 'Y',
      stopedAtndngSchoolDt: nil
    }
  end

  context 'with va_dependents_v2 turned off' do

    describe '#params_for_686c' do
      it 'formats child student params for submission' do
        formatted_info = child_student_info.params_for_686c

        expect(formatted_info).to eq(formatted_params_result)
      end
    end
  end

  context 'with va_dependents_v2 turned on' do

    describe '#params_for_686c' do
      it 'formats child student params for submission' do
        formatted_info = child_student_info_v2.params_for_686c_v2

        expect(formatted_info).to eq(formatted_params_result_v2)
      end
    end
  end
end
