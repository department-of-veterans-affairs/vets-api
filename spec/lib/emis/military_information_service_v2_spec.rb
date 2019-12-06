# frozen_string_literal: true

require 'rails_helper'
require 'emis/military_information_service_v2'

describe EMIS::MilitaryInformationServiceV2 do
  describe 'get_military_service_episodes' do
    context 'with a valid request' do
      let(:edipi) { '1007697216' }

      it 'calls the get_military_service_episodes endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_military_service_episodes/valid_v2') do
          response = subject.get_military_service_episodes(edipi: edipi)
          expect(response).to be_ok
        end
      end

      it 'includes new fields from v2' do
        VCR.use_cassette('emis/get_military_service_episodes/valid_v2') do
          response = subject.get_military_service_episodes(edipi: edipi)

          first_item = response.items.first
          expect(first_item.narrative_reason_for_separation_txt).to eq('UNKNOWN')
          expect(first_item.pay_plan_code).to eq('MW')
          expect(first_item.pay_grade_code).to eq('04')
          expect(first_item.service_rank_name_code).to eq('CW4')
          expect(first_item.service_rank_name_txt).to eq('Chief Warrant Officer')
          expect(first_item.pay_grade_date).to eq(Date.parse('2002-02-02'))
        end
      end
    end

    context 'with a valid request for episodes with no end date' do
      let(:edipi) { '1005123832' }

      it 'calls the get_military_service_episodes endpoint with a proper emis message' do
        VCR.use_cassette('emis/get_military_service_episodes/valid_no_end_date_v2') do
          response = subject.get_military_service_episodes(edipi: edipi)
          expect(response).to be_ok
        end
      end
    end
  end
end
