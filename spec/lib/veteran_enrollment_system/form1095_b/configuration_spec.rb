# frozen_string_literal: true

require 'rails_helper'
require 'veteran_enrollment_system/form1095_b/configuration'

describe 'VeteranEnrollmentSystem::Form1095B::Configuration' do
  subject { VeteranEnrollmentSystem::Form1095B::Configuration.instance }

  describe '.api_key_path' do
    it 'returns the api key path' do
      expect(VeteranEnrollmentSystem::Form1095B::Configuration.api_key_path).to eq(:form1095b)
    end
  end

  describe '#service_name' do
    it 'returns the base path' do
      expect(subject.service_name).to eq('VeteranEnrollmentSystem/Form1095B')
    end
  end
end
