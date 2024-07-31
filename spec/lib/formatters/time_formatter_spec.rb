# frozen_string_literal: true

require 'rails_helper'
require 'formatters/time_formatter'

describe Formatters::TimeFormatter do
  describe '.humanize' do
    it 'returns single second' do
      secs = 1
      output = described_class.humanize(secs)
      expect(output).to eq '1 second'
    end

    it 'returns plural seconds' do
      secs = 59
      output = described_class.humanize(secs)
      expect(output).to eq '59 seconds'
    end

    it 'returns singular minute second' do
      secs = 61
      output = described_class.humanize(secs)
      expect(output).to eq '1 minute 1 second'
    end

    it 'returns plural minutes seconds' do
      secs = 128
      output = described_class.humanize(secs)
      expect(output).to eq '2 minutes 8 seconds'
    end

    it 'returns singular hour' do
      secs = 3600
      output = described_class.humanize(secs)
      expect(output).to eq '1 hour'
    end

    it 'returns plural hours' do
      secs = 7200
      output = described_class.humanize(secs)
      expect(output).to eq '2 hours'
    end

    it 'returns string if given a float' do
      secs = 940_913.38729661
      output = described_class.humanize(secs)
      expect(output).to eq '10 days 21 hours 21 minutes 53 seconds'
    end

    it 'returns string if given an integer' do
      secs = 940_913
      output = described_class.humanize(secs)
      expect(output).to eq '10 days 21 hours 21 minutes 53 seconds'
    end
  end
end
