# frozen_string_literal: true

require 'rails_helper'
require 'emis/responses/get_guard_reserve_service_periods_response'

describe EMIS::Responses::GetGuardReserveServicePeriodsResponse do
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:body) { Ox.parse(File.read('spec/support/emis/getGuardReserveServicePeriodsResponse.xml')) }
  let(:response) { EMIS::Responses::GetGuardReserveServicePeriodsResponse.new(faraday_response) }

  before(:each) do
    allow(faraday_response).to receive(:body) { body }
  end

  describe 'checking status' do
    it 'returns true for ok?' do
      expect(response).to be_ok
    end
  end

  describe 'getting data' do
    context 'with a successful response' do
      it 'gives me an item' do
        expect(response.items.count).to eq(1)
      end

      it 'has the proper segment identifier' do
        expect(response.items.first.segment_identifier).to eq('3')
      end

      it 'has the proper begin date' do
        expect(response.items.first.begin_date).to eq(Date.parse('2007-05-22'))
      end

      it 'has the proper end date' do
        expect(response.items.first.end_date).to eq(Date.parse('2008-06-05'))
      end

      it 'has the proper termination reason' do
        expect(response.items.first.termination_reason).to eq('C')
      end

      it 'has the proper zone character of service code' do
        expect(response.items.first.character_of_service_code).to eq('H')
      end

      it 'has the correct narrative reason for separation code' do
        expect(response.items.first.narrative_reason_for_separation_code).to eq('999')
      end

      it 'has the right statute code' do
        expect(response.items.first.statute_code).to eq('C')
      end

      it 'has the right project code' do
        expect(response.items.first.project_code).to eq('9GF')
      end

      it 'has the right post 911 GIBill loss category code' do
        expect(response.items.first.post_911_gibill_loss_category_code).to eq('06')
      end

      it 'has the right training indicator code' do
        expect(response.items.first.training_indicator_code).to eq('N')
      end
    end
  end
end
