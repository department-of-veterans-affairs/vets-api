# frozen_string_literal: true

require 'rails_helper'

describe Veteran::Service::Organization do
  it 'is valid with valid attributes' do
    expect(Veteran::Service::Organization.new(poa: '000')).to be_valid
  end

  it 'is not valid without a poa' do
    organization = Veteran::Service::Organization.new(poa: nil)
    expect(organization).not_to be_valid
  end

  describe '.find_within_max_distance' do
    before do
      create(:organization, poa: '456', long: -77.050552, lat: 38.820450,
                            location: 'POINT(-77.050552 38.820450)') # ~6 miles from Washington, D.C.

      create(:organization, poa: '789', long: -76.609383, lat: 39.299236,
                            location: 'POINT(-76.609383 39.299236)') # ~35 miles from Washington, D.C.

      create(:organization, poa: '123', long: -77.466316, lat: 38.309875,
                            location: 'POINT(-77.466316 38.309875)') # ~47 miles from Washington, D.C.

      create(:organization, poa: '246', long: -76.3483, lat: 39.5359,
                            location: 'POINT(-76.3483 39.5359)') # ~57 miles from Washington, D.C.
    end

    context 'when there are organizations within the max search distance' do
      it 'returns all organizations located within the default max distance' do
        # check within 50 miles of Washington, D.C.
        results = described_class.find_within_max_distance(-77.0369, 38.9072)

        expect(results.pluck(:poa)).to match_array(%w[123 456 789])
      end

      it 'returns all organizations located within the specified max distance' do
        # check within 40 miles of Washington, D.C.
        results = described_class.find_within_max_distance(-77.0369, 38.9072, 64_373.8)

        expect(results.pluck(:poa)).to match_array(%w[456 789])
      end
    end

    context 'when there are no organizations within the max search distance' do
      it 'returns an empty array' do
        # check within 1 mile of Washington, D.C.
        results = described_class.find_within_max_distance(-77.0369, 38.9072, 1609.344)

        expect(results).to eq([])
      end
    end
  end

  describe '.find_with_name_similar_to' do
    before do
      # word similarity value = 1
      create(:organization, poa: '456', name: 'Virginia Department of Veterans Services')

      # word similarity value = 0.575
      create(:organization, poa: '789', name: 'Washington Department of Veterans Affairs')

      # word similarity value = 0.318
      create(:organization, poa: '123', name: 'Vermont Office of Veterans Affairs')

      # word similarity value = 0.231
      create(:organization, poa: '246', name: 'Puerto Rico Veterans Advocate Office')
    end

    context 'when there are organizations with names similar to the search phrase' do
      it 'returns all organizations with names >= the word similarity threshold' do
        results = described_class.find_with_name_similar_to('Virginia Department of Veterans Services')

        expect(results.pluck(:poa)).to match_array(%w[123 456 789])
      end
    end

    context 'when there are no organizations with names similar to the search phrase' do
      it 'returns an empty array' do
        results = described_class.find_with_name_similar_to('American Legion')

        expect(results.pluck(:poa)).to eq([])
      end
    end
  end
end
