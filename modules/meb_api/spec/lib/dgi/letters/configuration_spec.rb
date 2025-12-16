# frozen_string_literal: true

require 'rails_helper'

describe MebApi::DGI::Letters::Configuration do
  subject(:config) { described_class.instance }

  let(:mock_enabled) { false }

  before do
    # stub nested Settings without using receive_message_chain
    allow(Settings.dgi.vets).to receive_messages(
      url: 'https://example.com',
      mock: mock_enabled
    )
  end

  after do
    # Clear the memoized connection to prevent state leakage to other tests
    config.instance_variable_set(:@conn, nil)
  end

  context 'when mock is disabled' do
    let(:mock_enabled) { false }

    it 'returns base_path' do
      expect(config.base_path).to eq('https://example.com')
    end

    it 'returns service_name' do
      expect(config.service_name).to eq('DGI/Letters')
    end

    it 'indicates mock is disabled' do
      expect(config).not_to be_mock_enabled
    end
  end

  context 'when mock is enabled' do
    let(:mock_enabled) { true }

    it 'indicates mock is enabled' do
      expect(config).to be_mock_enabled
    end
  end

  it 'memoizes the Faraday connection' do
    first_conn = config.connection
    expect(config.connection).to equal(first_conn)
  end
end
