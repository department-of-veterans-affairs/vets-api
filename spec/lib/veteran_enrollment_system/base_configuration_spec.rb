# frozen_string_literal: true

require 'rails_helper'
require 'veteran_enrollment_system/base_configuration'
require 'veteran_enrollment_system/associations/configuration'

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

  describe '#self.api_key' do
    context 'when the base configuration is used' do
      it 'returns nil' do
        expect(VeteranEnrollmentSystem::BaseConfiguration.api_key).to be_nil
      end
    end

    context 'when the api_key_path is not defined for a subclass' do
      it 'raises an error' do
        expect do
          VeteranEnrollmentSystem::Associations::Configuration.api_key
        end.to raise_error('api_key_path must be defined in subclass')
      end
    end

    context 'when the api_key_path is defined for a subclass' do
      it 'returns the API key from the env settings' do
        # The api_key is set to `~` in `config/settings/test.yml`, which is nil
        expect(VeteranEnrollmentSystem::Associations::Configuration.api_key(:associations)).to eq(nil)
      end
    end
  end

  describe '#connection' do
    it 'returns a faraday connection' do
      expect(subject.connection).to be_a(Faraday::Connection)
    end
  end
end
