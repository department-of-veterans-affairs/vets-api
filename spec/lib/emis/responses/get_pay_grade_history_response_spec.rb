# frozen_string_literal: true

require 'rails_helper'
require 'emis/responses/get_pay_grade_history_response'

describe EMIS::Responses::GetPayGradeHistoryResponse do
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:body) { Ox.parse(File.read('spec/support/emis/getPayGradeHistoryResponse.xml')) }
  let(:response) { EMIS::Responses::GetPayGradeHistoryResponse.new(faraday_response) }
  let(:first_item) { response.items.first }

  before do
    allow(faraday_response).to receive(:body) { body }
  end

  describe 'checking status' do
    it 'returns true for ok?' do
      expect(response).to be_ok
    end
  end

  describe 'getting data' do
    context 'with a successful response' do
      it 'gives multiple items' do
        expect(response.items.count).to eq(2)
      end

      it 'has the proper personnel organization code' do
        expect(first_item.personnel_organization_code).to be_a(String).and eq('42')
      end

      it 'has the proper personnel category type code' do
        expect(first_item.personnel_category_type_code).to be_a(String).and eq('V')
      end

      it 'has the proper personnel segment identifier' do
        expect(first_item.personnel_segment_identifier).to be_a(String).and eq('1')
      end

      it 'has the proper pay plan code' do
        expect(first_item.pay_plan_code).to be_a(String).and eq('ME')
      end

      it 'has the proper pay grade code' do
        expect(first_item.pay_grade_code).to be_a(String).and eq('04')
      end

      it 'has the proper service rank name code' do
        expect(first_item.service_rank_name_code).to be_a(String).and eq('SRA')
      end

      it 'has the proper service rank name text' do
        expect(first_item.service_rank_name_txt).to be_a(String).and eq('Senior Airman')
      end

      it 'has the proper pay grade date' do
        expect(first_item.pay_grade_date).to be_a(Date).and eq(Date.parse('2009-04-12'))
      end
    end
  end
end
