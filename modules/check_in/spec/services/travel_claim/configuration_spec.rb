# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelClaim::Configuration do
  subject { described_class.instance }

  describe '#service_name' do
    it 'has a service name' do
      expect(subject.service_name).to eq('BTSSS-API')
    end
  end

  describe '#base_path' do
    it 'has a base path' do
      expect(subject.base_path).to be_present
      expect(subject.base_path).to be_a(String)
    end
  end

  describe '#connection' do
    it 'has a connection' do
      expect(subject.connection).to be_an_instance_of(Faraday::Connection)
    end

    it 'configures the connection with proper middleware' do
      connection = subject.connection

      # Check that JSON middleware is configured
      expect(connection.builder.handlers.map(&:name)).to include('Faraday::Request::Json')
      expect(connection.builder.handlers.map(&:name)).to include('Faraday::Response::Json')
    end

    it 'uses the correct base URL' do
      expected_url = subject.base_path.end_with?('/') ? subject.base_path : "#{subject.base_path}/"
      expect(subject.connection.url_prefix.to_s).to eq(expected_url)
    end
  end

  describe 'singleton behavior' do
    it 'returns the same instance' do
      instance1 = described_class.instance
      instance2 = described_class.instance

      expect(instance1).to be(instance2)
    end
  end

  describe 'inheritance' do
    it 'inherits from Common::Client::Configuration::REST' do
      expect(described_class.superclass).to eq(Common::Client::Configuration::REST)
    end

    it 'includes Singleton' do
      expect(described_class.included_modules).to include(Singleton)
    end
  end

  describe '#mock_enabled?' do
    context 'when flipper flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with('check_in_experience_mock_enabled').and_return(true)
      end

      it 'returns true' do
        expect(subject.send(:mock_enabled?)).to be true
      end
    end

    context 'when flipper flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with('check_in_experience_mock_enabled').and_return(false)
      end

      it 'returns false' do
        expect(subject.send(:mock_enabled?)).to be false
      end
    end
  end
end
