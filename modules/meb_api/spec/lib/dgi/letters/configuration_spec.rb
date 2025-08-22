require 'rails_helper'

describe MebApi::DGI::Letters::Configuration do
  subject(:config) { described_class.instance }

  let(:mock_enabled) { false }

  before do
    allow(Settings).to receive_message_chain(:dgi, :vets, :url).and_return('https://example.com')
    allow(Settings).to receive_message_chain(:dgi, :vets, :mock).and_return(mock_enabled)
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
      expect(config.mock_enabled?).to be_falsey
    end
  end

  context 'when mock is enabled' do
    let(:mock_enabled) { true }

    it 'indicates mock is enabled' do
      expect(config.mock_enabled?).to be_truthy
    end
  end

  it 'memoizes the Faraday connection' do
    first_conn = config.connection
    expect(config.connection).to equal(first_conn)
  end
end
