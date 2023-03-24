# frozen_string_literal: true

require 'rails_helper'
require 'string_helpers'

describe StringHelpers do
  context 'capitalize_only' do
    it 'capitalizes fooBar to FooBar' do
      expect(described_class.capitalize_only('fooBar')).to eq('FooBar')
    end

    it 'capitalizes FooBar to FooBar' do
      expect(described_class.capitalize_only('FooBar')).to eq('FooBar')
    end
  end

  describe '#hyphenated_ssn' do
    it 'hyphenates the ssn' do
      expect(described_class.hyphenated_ssn('111221234')).to eq('111-22-1234')
    end
  end

  describe '#mask_sensitive' do
    it 'replaces part of the string with asterisks' do
      expect(described_class.mask_sensitive('sdkfjsdklflsdf')).to eq('**********lsdf')
    end
  end

  context 'levenshtein_distance' do
    fixtures = [
      ['hello', 'hello', 0],
      ['hello', 'helo', 1],
      ['hello', 'jello', 1],
      ['hello', 'hellol', 1],
      ['hello', 'helol', 2],
      ['hello', 'heloll', 2],
      ['hello', 'cheese', 4],
      ['hello', 'saint', 5],
      ['hello', '', 5]
    ]

    fixtures.each do |w1, w2, d|
      it "calculates a distance of #{d} between #{w1} and #{w2}" do
        expect(described_class.levenshtein_distance(w1, w2)).to eq(d)
        expect(described_class.levenshtein_distance(w2, w1)).to eq(d)
      end
    end

    it 'raises an error if either argument is nil' do
      expect { described_class.levenshtein_distance('', nil) }.to raise_error NoMethodError
      expect { described_class.levenshtein_distance(nil, '') }.to raise_error NoMethodError
    end

    it 'raises an error if either argument is something else than a string' do
      expect { described_class.levenshtein_distance('woah', /woah/) }.to raise_error NoMethodError
      expect { described_class.levenshtein_distance(5.3, '5.3') }.to raise_error NoMethodError
      expect { described_class.levenshtein_distance(Object.new, 'Hello') }.to raise_error NoMethodError
    end
  end

  context 'heuristics' do
    # rubocop:disable Layout/LineLength
    fixtures = [
      ['319111111', '319111111', { length: [9, 9], only_digits: [true, true], encoding: %w[UTF-8 UTF-8], levenshtein_distance: 0 }],
      ['319121111', '319111111', { length: [9, 9], only_digits: [true, true], encoding: %w[UTF-8 UTF-8], levenshtein_distance: 1 }],
      ['319-11-1111', '319111111', { length: [11, 9], only_digits: [false, true], encoding: %w[UTF-8 UTF-8], levenshtein_distance: 2 }],
      ['319-11-1111', '319-11-1111', { length: [11, 11], only_digits: [false, false], encoding: %w[UTF-8 UTF-8], levenshtein_distance: 0 }]
    ]
    # rubocop:enable Layout/LineLength

    fixtures.each do |w1, w2, heuristic_hash|
      it "returns heuristics hash #{heuristic_hash}" do
        expect(described_class.heuristics(w1, w2)).to eq(heuristic_hash)
      end
    end
  end

  context 'filtered_endpoint_tag' do
    it 'group labels facility v2 endpoints' do
      facility_v2_path = '/facilities/v2/facilities/983GC'
      facility_v2_filtered = '/facilities/v2/facilities/xxx'
      expect(described_class.filtered_endpoint_tag(facility_v2_path)).to eq(facility_v2_filtered)
    end

    it 'group labels VAMF partial errors' do
      vamf_partial_error = 'Could not get appointments from VistA Scheduling Service (20b69580-b51e-4f77-8358-99f2923)'
      vamf_partial_filtered = 'Could not get appointments from VistA Scheduling Service <id>'
      expect(described_class.filtered_endpoint_tag(vamf_partial_error)).to eq(vamf_partial_filtered)
    end

    it 'group labels locations v1 clinics endpoints' do
      location_v1_clinics = '/vaos/v1/locations/512A5/clinics'
      location_v1_clinics_filtered = '/vaos/v1/locations/xxx/clinics'
      expect(described_class.filtered_endpoint_tag(location_v1_clinics)).to eq(location_v1_clinics_filtered)
    end
  end
end
