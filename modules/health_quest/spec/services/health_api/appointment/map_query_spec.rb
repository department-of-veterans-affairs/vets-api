# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::HealthApi::Appointment::MapQuery do
  subject { described_class }

  let(:session_store) { double('SessionStore', token: '123abc') }
  let(:client) { double('HealthQuest::Lighthouse::FHIRClient') }

  describe 'included modules' do
    it 'includes Lighthouse::FHIRClient' do
      expect(subject.ancestors).to include(HealthQuest::Lighthouse::FHIRClient)
    end

    it 'includes Lighthouse::FHIRHeaders' do
      expect(subject.ancestors).to include(HealthQuest::Lighthouse::FHIRHeaders)
    end
  end

  describe '.build' do
    it 'returns an instance of MapQuery' do
      expect(subject.build(session_store)).to be_an_instance_of(subject)
    end
  end

  describe 'object initialization' do
    it 'has a headers attribute' do
      expect(subject.new(session_store).respond_to?(:headers)).to eq(true)
    end
  end

  describe '#fhir_model' do
    it 'is a FHIR::Appointment class' do
      expect(subject.new(session_store).fhir_model).to eq(FHIR::Appointment)
    end
  end
end
