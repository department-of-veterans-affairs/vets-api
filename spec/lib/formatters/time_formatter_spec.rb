# frozen_string_literal: true

require 'rails_helper'
require 'formatters/time_formatter'

describe Formatters::TimeFormatter do
  describe '.humanize' do
    it 'returns single digit seconds' do
      secs = 1
      output = described_class.humanize(secs)
      expect(output).to eq '1 seconds'
    end

    it 'returns double digit seconds' do
      secs = 59
      output = described_class.humanize(secs)
      expect(output).to eq '59 seconds'
    end

    it 'returns string if given a float' do
      secs = 940913.38729661
      output = described_class.humanize(secs)
      expect(output).to eq '10 days 21 hours 21 minutes 53 seconds'
    end

    it 'returns string if given an integer' do
      secs = 940913
      output = described_class.humanize(secs)
      expect(output).to eq '10 days 21 hours 21 minutes 53 seconds'
    end
  end
end
