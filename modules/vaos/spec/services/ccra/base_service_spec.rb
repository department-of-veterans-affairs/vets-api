# frozen_string_literal: true

require 'rails_helper'

describe Ccra::BaseService do
  subject { described_class.new(user) }

  let(:user) { double('User', account_uuid: '1234') }

  describe '#headers' do
    let(:request_id) { '123456-abcdef' }

    before do
      RequestStore.store['request_id'] = request_id
    end

    it 'returns the expected headers' do
      expect(subject.headers).to eq(
        'Content-Type' => 'application/json',
        'X-Request-ID' => request_id
      )
    end
  end

  describe '#config' do
    it 'returns a Ccra::Configuration instance' do
      expect(subject.config).to be_a(Ccra::Configuration)
    end

    it 'memoizes the configuration' do
      config = subject.config
      expect(subject.config).to equal(config)
    end
  end

  describe 'monitoring' do
    it 'includes monitoring concern' do
      expect(described_class.ancestors).to include(Common::Client::Concerns::Monitoring)
    end

    it 'sets the correct statsd key prefix' do
      expect(described_class::STATSD_KEY_PREFIX).to eq('api.ccra')
    end
  end
end
