# frozen_string_literal: true

require 'rails_helper'
require 'veteran_enrollment_system/associations/configuration'

describe 'VeteranEnrollmentSystem::Associations::Configuration' do
  subject { VeteranEnrollmentSystem::Associations::Configuration.instance }

  describe '#self.api_key_path' do
    it 'returns the base request headers' do
      expect(VeteranEnrollmentSystem::Associations::Configuration.api_key_path).to eq(:associations)
    end
  end
end
