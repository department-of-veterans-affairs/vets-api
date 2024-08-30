# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V1::FHIRConfiguration do
  subject { VAOS::V1::FHIRConfiguration.instance }

  describe '#service_name' do
    it 'has a service name' do
      expect(subject.service_name).to eq('VAOS::FHIR')
    end
  end

  describe '#connection' do
    it 'returns a connection' do
      expect(subject.connection).not_to be_nil
    end
  end

  describe '#read_timeout' do
    it 'has a default timeout of 25 seconds' do
      expect(subject.read_timeout).to eq(25)
    end
  end
end
