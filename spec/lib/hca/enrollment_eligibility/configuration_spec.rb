# frozen_string_literal: true

require 'rails_helper'
require 'hca/enrollment_eligibility/configuration'

describe HCA::EnrollmentEligibility::Configuration do
  subject { described_class.instance }

  describe '#base_path' do
    it 'has a base path' do
      expect(subject.base_path).to eq(Settings.hca.ee.endpoint)
    end
  end

  describe '#service_name' do
    it 'has a service name' do
      expect(subject.service_name).to eq('HCA_EE')
    end
  end

  describe '#connection' do
    it 'has a connection' do
      expect(subject.connection).to be_an_instance_of(Faraday::Connection)
    end
  end
end
