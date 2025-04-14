# frozen_string_literal: true

require 'rails_helper'
require 'veteran_enrollment_system/associations/configuration'

describe 'VeteranEnrollmentSystem::Associations::Configuration' do
  subject { VeteranEnrollmentSystem::Associations::Configuration.instance }

  describe '#base_path' do
    it 'returns the base path' do
      expect(subject.base_path).to eq(
        "#{Settings.veteran_enrollment_system.host}/ves-associate-gateway-svc/associations/person/"
      )
    end
  end

  describe '#self.api_key_path' do
    it 'returns the api key path' do
      expect(VeteranEnrollmentSystem::Associations::Configuration.api_key_path).to eq(:associations)
    end
  end
end
