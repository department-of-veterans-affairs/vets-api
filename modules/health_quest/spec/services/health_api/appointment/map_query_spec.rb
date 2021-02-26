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

  describe '#api_query_path' do
    it 'returns the health api path' do
      expect(subject.new(session_store).api_query_path).to eq('/services/fhir/v0/r4')
    end
  end

  describe '#fhir_model' do
    it 'is a FHIR::Appointment class' do
      expect(subject.new(session_store).fhir_model).to eq(FHIR::Appointment)
    end
  end

  describe '#search_options' do
    let(:options) { { search: { parameters: { patient: '12345678' } } } }

    it 'builds options' do
      expect(subject.new(session_store).search_options(patient: '12345678')).to eq(options)
    end
  end

  describe '#search' do
    context 'with valid options' do
      let(:options) do
        {
          search: {
            parameters: { patient: '12345678' }
          }
        }
      end

      before do
        allow_any_instance_of(subject).to receive(:client).and_return(client)
      end

      it 'calls search on the FHIR client' do
        expect(client).to receive(:search).with(FHIR::Appointment, options).exactly(1).time

        subject.build(session_store).search(patient: '12345678')
      end
    end
  end
end
