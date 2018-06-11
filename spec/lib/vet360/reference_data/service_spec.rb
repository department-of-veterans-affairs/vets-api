# frozen_string_literal: true

require 'rails_helper'

describe Vet360::ReferenceData::Service, skip_vet360: true do
  subject { described_class.new }

  before { Timecop.freeze('2018-04-09T17:52:03Z') }
  after  { Timecop.return }

  describe '#countries' do
    context 'when successful' do
      it 'returns a status of 200', :aggregate_failures do
        VCR.use_cassette('vet360/reference_data/countries', VCR::MATCH_EVERYTHING) do
          response = subject.countries

          expect(response).to be_ok
          expect(response.countries).to be_a(Array)

          data = response.countries.first
          expect(data).to have_key('country_name')
          expect(data).to have_key('country_code_iso2')
          expect(data).to have_key('country_code_iso3')
          expect(data).to have_key('country_code_fips')
        end
      end
    end
  end

  describe '#states' do
    context 'when successful' do
      it 'returns a status of 200', :aggregate_failures do
        VCR.use_cassette('vet360/reference_data/states', VCR::MATCH_EVERYTHING) do
          response = subject.states

          expect(response).to be_ok
          expect(response.states).to be_a(Array)

          data = response.states.first
          expect(data).to have_key('state_name')
          expect(data).to have_key('state_code')
        end
      end
    end
  end

  describe '#zipcodes' do
    context 'when successful' do
      it 'returns a status of 200', :aggregate_failures do
        VCR.use_cassette('vet360/reference_data/zipcodes', VCR::MATCH_EVERYTHING) do
          response = subject.zipcodes

          expect(response).to be_ok
          expect(response.zipcodes).to be_a(Array)

          data = response.zipcodes.first
          expect(data).to have_key('zip_code')
        end
      end
    end
  end
end
