# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Idp::Client do
  describe '#initialize' do
    it 'raises an error when base_url is not configured' do
      expect { described_class.new(base_url: nil) }
        .to raise_error(Idp::Error, /IDP base URL is not configured/)
    end

    it 'initializes successfully with a base_url' do
      expect { described_class.new(base_url: 'https://example.com') }.not_to raise_error
    end

    it 'uses the default timeout when none is provided' do
      client = described_class.new(base_url: 'https://example.com')
      expect(client.send(:timeout)).to eq(Idp::Client::DEFAULT_TIMEOUT)
    end

    it 'accepts a custom timeout' do
      client = described_class.new(base_url: 'https://example.com', timeout: 30)
      expect(client.send(:timeout)).to eq(30)
    end
  end
end
