# frozen_string_literal: true

require 'rails_helper'
require 'string_helpers'

describe StringHelpers do
  context 'capitalize_only' do
    it 'should capitalize fooBar to FooBar' do
      expect(described_class.capitalize_only('fooBar')).to eq('FooBar')
    end

    it 'should capitalize FooBar to FooBar' do
      expect(described_class.capitalize_only('FooBar')).to eq('FooBar')
    end
  end

  context 'levenshtein_distance' do
    fixtures = [
      ['hello', 'hello', 0],
      ['hello', 'helo', 1],
      ['hello', 'jello', 1],
      ['hello', 'helol', 1],
      ['hello', 'hellol', 1],
      ['hello', 'heloll', 2],
      ['hello', 'cheese', 4],
      ['hello', 'saint', 5],
      ['hello', '', 5]
    ]

    fixtures.each do |w1, w2, d|
      it "should calculate a distance of #{d} between #{w1} and #{w2}" do
        expect(described_class.levenshtein_distance(w1, w2)).to eq(d)
        expect(described_class.levenshtein_distance(w2, w1)).to eq(d)
      end
    end

    it 'should raise an error if either argument is nil' do
      expect { described_class.levenshtein_distance('', nil) }.to raise_error TypeError
      expect { described_class.levenshtein_distance(nil, '') }.to raise_error TypeError
    end

    it 'should raise an error if either argument is something else than a string' do
      expect { described_class.levenshtein_distance('woah', /woah/) }.to raise_error TypeError
      expect { described_class.levenshtein_distance(5.3, '5.3') }.to raise_error TypeError
      expect { described_class.levenshtein_distance(Object.new, 'Hello') }.to raise_error TypeError
    end
  end

  context 'heuristics' do
    # rubocop:disable LineLength
    fixtures = [
      ['319111111', '319111111', { length: [9, 9], only_digits: [true, true], encoding: ['UTF-8', 'UTF-8'], levenshtein_distance: 0 }],
      ['319121111', '319111111', { length: [9, 9], only_digits: [true, true], encoding: ['UTF-8', 'UTF-8'], levenshtein_distance: 1 }],
      ['319-11-1111', '319111111', { length: [11, 9], only_digits: [false, true], encoding: ['UTF-8', 'UTF-8'], levenshtein_distance: 2 }],
      ['319-11-1111', '319-11-1111', { length: [11, 11], only_digits: [false, false], encoding: ['UTF-8', 'UTF-8'], levenshtein_distance: 0 }]
    ]
    # rubocop:enable LineLength

    fixtures.each do |w1, w2, heuristic_hash|
      it "should return heuristics hash #{heuristic_hash} " do
        expect(described_class.heuristics(w1, w2)).to eq(heuristic_hash)
      end
    end
  end
end
