# frozen_string_literal: true

require 'rails_helper'
require 'veteran_enrollment_system/enrollment_periods/configuration'

describe 'VeteranEnrollmentSystem::EnrollmentPeriods::Configuration' do
  subject { VeteranEnrollmentSystem::EnrollmentPeriods::Configuration.instance }

  describe '.api_key_path' do
    it 'returns the api key path' do
      expect(VeteranEnrollmentSystem::EnrollmentPeriods::Configuration.api_key_path).to eq(:enrollment_periods)
    end
  end

  describe '#service_name' do
    it 'returns the base path' do
      expect(subject.service_name).to eq('VeteranEnrollmentSystem/EnrollmentPeriods')
    end
  end
end
