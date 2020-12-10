# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::FacilityLookupService do
  subject { described_class.new }

  describe '#facilities_for' do
    describe 'with invalid zip codes' do
      it 'returns a default response' do
        expect(subject.facilities_for('00001')).not_to include(:zip_code)
        expect(subject.facilities_for('00001')).not_to include(:sta3n)
        expect(subject.facilities_for('00001')).not_to include(:sta6a)
      end
    end

    describe 'with nil zip code' do
      it 'returns a default response' do
        expect(subject.facilities_for(nil)).not_to include(:zip_code)
        expect(subject.facilities_for('00001')).not_to include(:sta3n)
        expect(subject.facilities_for('00001')).not_to include(:sta6a)
      end
    end

    context 'a location near a VAMC' do
      it 'includes zipcode lat/long' do
        VCR.use_cassette('covid_vaccine/facilities/query_97214', match_requests_on: %i[path query]) do
          result = subject.facilities_for('97214')
          expect(result).to include(:zip_code, :zip_lat, :zip_lon)
        end
      end

      it 'returns facilities including a VAMC' do
        VCR.use_cassette('covid_vaccine/facilities/query_97214', match_requests_on: %i[path query]) do
          result = subject.facilities_for('97214')
          expect(result[:sta3n]).to eq '648'
          expect(result[:sta6a]).to eq '648GI'
        end
      end

      it 'returns only a sta3n if closest to a VAMC' do
        VCR.use_cassette('covid_vaccine/facilities/query_97204', match_requests_on: %i[path query]) do
          result = subject.facilities_for('97204')
          expect(result[:sta3n]).to eq '648'
          expect(result[:sta6a]).to be_nil
        end
      end
    end

    context 'a remote location' do
      it 'returns facilities including a VAMC' do
        VCR.use_cassette('covid_vaccine/facilities/query_99766', match_requests_on: %i[path query]) do
          result = subject.facilities_for('99766')
          expect(result[:sta3n]).to eq '463'
          expect(result[:sta6a]).to eq '463GA'
        end
      end
    end

    context 'a location near a consolidated facility' do
      it 'returns nearest VAMC as a sta6a' do
        VCR.use_cassette('covid_vaccine/facilities/query_13210', match_requests_on: %i[path query]) do
          result = subject.facilities_for('13210')
          expect(result[:sta3n]).to be_nil
          expect(result[:sta6a]).to eq '528A7'
        end
      end
    end

    context 'a location near a colocated VBA facility' do
      it 'does not include the VBA facility ID' do
        VCR.use_cassette('covid_vaccine/facilities/query_04330', match_requests_on: %i[path query]) do
          result = subject.facilities_for('04330')
          expect(result[:sta6a]).not_to start_with('vba_')
        end
      end
    end

    context 'with a timeout error from the facilities API' do
      it 'returns empty facility info' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
        result = subject.facilities_for('97214')
        expect(result[:zip_code]).to eq '97214'
        expect(result[:sta3n]).to be_nil
        expect(result[:sta6a]).to be_nil
      end
    end

    context 'with any error from the facilities nearby API' do
      it 'returns empty facility info' do
        allow_any_instance_of(Lighthouse::Facilities::Client).to receive(:nearby)
          .and_raise(StandardError.new('facilities exception'))
        result = subject.facilities_for('97214')
        expect(result[:zip_code]).to eq '97214'
        expect(result[:sta3n]).to be_nil
        expect(result[:sta6a]).to be_nil
      end
    end

    context 'with any error from the facilities API' do
      it 'returns empty facility info' do
        allow_any_instance_of(Lighthouse::Facilities::Client).to receive(:get_facilities)
          .and_raise(StandardError.new('facilities exception'))
        result = subject.facilities_for('97214')
        expect(result[:zip_code]).to eq '97214'
        expect(result[:sta3n]).to be_nil
        expect(result[:sta6a]).to be_nil
      end
    end
  end
end
