# frozen_string_literal: true

require 'rails_helper'
require 'emis/responses/get_combat_pay_response'

describe EMIS::Responses::GetCombatPayResponse do
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:body) { Ox.parse(File.read('spec/support/emis/getCombatPayResponse.xml')) }
  let(:response) { EMIS::Responses::GetCombatPayResponse.new(faraday_response) }

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
        expect(response.items.first.segment_identifier).to eq('1')
      end

      it 'has the proper begin date' do
        expect(response.items.first.begin_date).to eq(Date.parse('2008-09-08'))
      end

      it 'has the proper end date' do
        expect(response.items.first.end_date).to eq(Date.parse('2009-04-18'))
      end

      it 'has the proper type code' do
        expect(response.items.first.type_code).to eq('01')
      end

      it 'has the proper zone country code' do
        expect(response.items.first.combat_zone_country_code).to eq('AE')
      end
    end
  end
end
