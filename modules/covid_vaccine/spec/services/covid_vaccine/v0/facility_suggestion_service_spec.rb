# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::FacilitySuggestionService do
  subject { described_class.new }

  describe '#facilities_for' do
    context 'a location near a VAMC' do
      it 'returns results' do
        VCR.use_cassette('covid_vaccine/facilities/query_60607', match_requests_on: %i[path query]) do
          result = subject.facilities_for('60607')
          expect(result.length).to eq(3)
        end
      end
    end

    context 'with additional facilities in allow list' do
      it 'returns only configured facilities' do
        VCR.use_cassette('covid_vaccine/facilities/query_95959', match_requests_on: %i[path query]) do
          with_settings(Settings.covid_vaccine, allowed_facilities: ['612A4', '612GF', 654]) do
            result = subject.facilities_for('95959', 10)
            expect(result.length).to eq(3)
          end
        end
      end
    end

    context 'with a timeout error from the facilities API' do
      it 'returns empty facility info' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
        expect { subject.facilities_for('97214') }.to raise_error(StandardError)
      end
    end

    context 'with any error from the facilities API' do
      it 'returns empty facility info' do
        allow_any_instance_of(Lighthouse::Facilities::Client).to receive(:get_facilities)
          .and_raise(StandardError.new('facilities exception'))
        expect { subject.facilities_for('97214') }.to raise_error(StandardError)
      end
    end
  end
end
