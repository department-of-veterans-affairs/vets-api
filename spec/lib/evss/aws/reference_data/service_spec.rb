# frozen_string_literal: true

require 'rails_helper'

describe EVSS::ReferenceData::Service do
  let(:user) { build(:user, :loa3) }
  subject { described_class.new(user) }

  describe '#get_countries' do
    context 'with a 200 response' do
      it 'returns a list of countries' do
        VCR.use_cassette('evss/reference_data/countries') do
          response = subject.get_countries
          expect(response).to be_ok
          expect(response.countries[0...10]).to eq(
            %w[Afghanistan Albania Algeria Angola Anguilla Antigua Antigua\ and\ Barbuda Argentina Armenia Australia]
          )
        end
      end
    end
  end

  describe '#get_states' do
    context 'with a 200 response' do
      it 'returns a list of states' do
        VCR.use_cassette('evss/reference_data/states') do
          response = subject.get_states
          expect(response).to be_ok
          expect(response.states[0...11]).to eq(
            %w[AK AL AR AS AZ CA CO CT DC DE FL]
          )
        end
      end
    end
  end
end
