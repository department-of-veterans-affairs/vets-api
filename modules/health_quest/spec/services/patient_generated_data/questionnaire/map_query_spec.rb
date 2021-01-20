# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::PatientGeneratedData::Questionnaire::MapQuery do
  subject { described_class }

  let(:headers) { { 'Accept' => 'application/json+fhir' } }
  let(:client) { double('HealthQuest::PatientGeneratedData::FHIRClient') }

  describe 'included modules' do
    it 'includes PatientGeneratedData::FHIRClient' do
      expect(subject.ancestors).to include(HealthQuest::PatientGeneratedData::FHIRClient)
    end
  end

  describe '.build' do
    it 'returns an instance of MapQuery' do
      expect(subject.build(headers)).to be_an_instance_of(subject)
    end
  end

  describe 'object initialization' do
    it 'has a headers attribute' do
      expect(subject.new({}).respond_to?(:headers)).to eq(true)
    end
  end

  describe '#fhir_model' do
    it 'is a FHIR::Questionnaire class' do
      expect(subject.new({}).fhir_model).to eq(FHIR::Questionnaire)
    end
  end

  describe '#search' do
    context 'with valid options' do
      let(:options) do
        {
          search: {
            parameters: { author: '123' }
          }
        }
      end

      before do
        allow_any_instance_of(subject).to receive(:client).and_return(client)
      end

      it 'calls search on the FHIR client' do
        expect(client).to receive(:search).with(FHIR::Questionnaire, options).exactly(1).time

        subject.build(headers).search(author: '123')
      end
    end
  end

  describe '#search_options' do
    let(:options) { { search: { parameters: { author: 'abc' } } } }

    it 'builds options' do
      expect(subject.new({}).search_options(author: 'abc')).to eq(options)
    end
  end

  describe '#get' do
    context 'with valid id' do
      let(:client) { double('HealthQuest::PatientGeneratedData::FHIRClient') }
      let(:id) { 'faae134c-9c7b-49d7-8161-10e314da4de1' }

      before do
        allow_any_instance_of(subject).to receive(:client).and_return(client)
      end

      it 'returns an instance of Reply' do
        expect(client).to receive(:read).with(FHIR::Questionnaire, id).exactly(1).time

        subject.build(headers).get(id)
      end
    end
  end
end
