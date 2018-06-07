# frozen_string_literal: true

require 'rails_helper'
require 'common/exceptions'

describe Vet360Redis::ReferenceData do
  let(:reference_data) { Vet360Redis::ReferenceData.new }
  let(:response) { Vet360::ReferenceData::Response.new(200, reference_data: data) }

  describe '#countries' do
    let(:data) do
      [
        {
          'country_name': 'Afghanistan',
          'country_code_iso2': '',
          'country_code_iso3': '',
          'country_code_fips': ''
        },
        {
          'country_name': 'Afghanistan',
          'country_code_iso2': '',
          'country_code_iso3': '',
          'country_code_fips': ''
        }
      ]
    end

    context 'when the cache is empty' do
      it 'should cache and return the response', :aggregate_failures do
        allow_any_instance_of(
          Vet360::ReferenceData::Service
        ).to receive(:countries).and_return(response)

        expect(reference_data.redis_namespace).to receive(:set).once
        expect_any_instance_of(Vet360::ReferenceData::Service).to receive(:countries).once
        expect(reference_data.countries).to have_deep_attributes(data)
      end
    end

    context 'when there is cached data' do
      it 'returns the cached data', :aggregate_failures do
        reference_data.cache('vet360_reference_data_countries', response)

        expect_any_instance_of(Vet360::ReferenceData::Service).to_not receive(:countries)
        expect(reference_data.countries).to have_deep_attributes(data)
      end
    end
  end
end
