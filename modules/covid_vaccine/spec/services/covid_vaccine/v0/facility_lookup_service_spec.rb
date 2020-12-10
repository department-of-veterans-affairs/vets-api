# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::FacilityLookupService do
  subject { described_class.new }

  describe '#facilities_for' do
    describe 'with invalid zip codes' do
      it 'returns a default response' do
        expect(subject.facilities_for('00001')).to include(zip: nil)
        expect(subject.facilities_for('00001')).not_to include(:zip_facilities)
      end
    end

    describe 'with nil zip code' do
      it 'returns a default response' do
        expect(subject.facilities_for(nil)).to include(zip: nil)
        expect(subject.facilities_for(nil)).not_to include(:zip_facilities)
      end
    end

    context 'a location near a VAMC' do
      it 'includes zipcode lat/long' do
        VCR.use_cassette('covid_vaccine/facilities/query_97214', match_requests_on: %i[path query]) do
          result = subject.facilities_for('97214')
          expect(result).to include(:zip, :zip_lat, :zip_lng)
        end
      end

      it 'returns facilities including a VAMC' do
        VCR.use_cassette('covid_vaccine/facilities/query_97214', match_requests_on: %i[path query]) do
          result = subject.facilities_for('97214')
          expect(result[:zip_facilities]).to be_truthy
          expect(result[:zip_facilities].last.length).to eq 3
        end
      end
    end

    context 'a remote location' do
      it 'returns facilities including a VAMC' do
        VCR.use_cassette('covid_vaccine/facilities/query_99766', match_requests_on: %i[path query]) do
          result = subject.facilities_for('99766')
          expect(result[:zip_facilities]).to be_truthy
          expect(result[:zip_facilities].last.length).to eq 3
        end
      end
    end

    context 'a location near a consolidated facility' do
      it 'returns facilities including a VAMC' do
        VCR.use_cassette('covid_vaccine/facilities/query_13210', match_requests_on: %i[path query]) do
          result = subject.facilities_for('13210')
          expect(result[:zip_facilities]).to be_truthy
          vamc = result[:zip_facilities].last
          expect(vamc).to eq '528A7'
          expect(described_class::CONSOLIDATED_FACILITIES).to include(vamc)
        end
      end
    end
  end
end
