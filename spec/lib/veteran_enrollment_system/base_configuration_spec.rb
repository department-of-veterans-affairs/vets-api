# frozen_string_literal: true

require 'rails_helper'
require 'veteran_enrollment_system/base_configuration'
require 'veteran_enrollment_system/associations/configuration'

# Test class used for testing BaseConfiguration
class TestConfiguration < VeteranEnrollmentSystem::BaseConfiguration
end

describe 'VeteranEnrollmentSystem::BaseConfiguration' do
  subject { VeteranEnrollmentSystem::BaseConfiguration.instance }

  describe '#base_path' do
    it 'returns the value from the env settings' do
      expect(subject.base_path).to eq('https://sqa.ves.va.gov/')
    end
  end

  describe '#service_name' do
    it 'overrides service_name with a unique name' do
      expect(subject.service_name).to eq('VeteranEnrollmentSystem')
    end
  end

  describe '#self.base_request_headers' do
    context 'when the api key is present' do
      it 'merges the api key with the base headers' do
        allow(VeteranEnrollmentSystem::BaseConfiguration).to receive(:api_key).and_return('test_key')
        expect(subject.base_request_headers).to include('apiKey' => 'test_key')
      end
    end

    context 'when the api key is not present' do
      it 'does not merge the api key in the base headers' do
        allow(VeteranEnrollmentSystem::BaseConfiguration).to receive(:api_key).and_return(nil)
        expect(subject.base_request_headers).not_to include('apiKey')
      end
    end
  end

  describe '#self.api_key' do
    context 'when the base configuration is used' do
      it 'returns nil' do
        expect(VeteranEnrollmentSystem::BaseConfiguration.api_key).to be_nil
      end
    end

    context 'when the api_key_path is not defined for a subclass' do
      it 'raises an error' do
        expect do
          TestConfiguration.api_key
        end.to raise_error('api_key_path must be defined in subclass')
      end
    end

    context 'when the api_key_path is defined for a subclass' do
      it 'returns the API key from the env settings' do
        expect(VeteranEnrollmentSystem::Associations::Configuration.api_key).to be_nil
      end
    end
  end

  describe '#connection' do
    it 'returns a Faraday connection' do
      expect(subject.connection).to be_a(Faraday::Connection)
    end
  end
end
