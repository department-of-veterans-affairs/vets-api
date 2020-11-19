# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::PatientGeneratedData::QuestionnaireResponse::MapQuery do
  subject { described_class }

  let(:headers) { { 'Accept' => 'application/json+fhir' } }

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

  describe '#dstu2_model' do
    it 'is a FHIR::DSTU2::QuestionnaireResponse class' do
      expect(subject.new({}).dstu2_model).to eq(FHIR::DSTU2::QuestionnaireResponse)
    end
  end

  describe '#search' do
    context 'with valid options' do
      let(:client) { double('HealthQuest::PatientGeneratedData::FHIRClient') }
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

      it 'returns an instance of Reply' do
        expect(client).to receive(:search).with(FHIR::DSTU2::QuestionnaireResponse, options).exactly(1).time

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
end
