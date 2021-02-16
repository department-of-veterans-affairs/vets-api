# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::PatientGeneratedData::QuestionnaireResponse::MapQuery do
  subject { described_class }

  let(:session_store) { double('SessionStore', token: '123abc') }
  let(:client) { double('HealthQuest::Lighthouse::FHIRClient') }

  describe 'included modules' do
    it 'includes Lighthouse::FHIRClient' do
      expect(subject.ancestors).to include(HealthQuest::Lighthouse::FHIRClient)
    end

    it 'includes PatientGeneratedData::FHIRHeaders' do
      expect(subject.ancestors).to include(HealthQuest::PatientGeneratedData::FHIRHeaders)
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
    it 'is a FHIR::QuestionnaireResponse class' do
      expect(subject.new(session_store).fhir_model).to eq(FHIR::QuestionnaireResponse)
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
        expect(client).to receive(:search).with(FHIR::QuestionnaireResponse, options).exactly(1).time

        subject.build(session_store).search(author: '123')
      end
    end
  end

  describe '#create' do
    let(:user) { double('User', icn: '1008596379V859838', first_name: 'Bob', last_name: 'Smith') }
    let(:questionnaire_response) do
      {
        appointment_id: 'abc123',
        questionnaire_response: {},
        questionnaire_id: 'abcd-1234'
      }
    end
    let(:data) do
      HealthQuest::PatientGeneratedData::QuestionnaireResponse::Resource
        .manufacture(questionnaire_response, user)
        .prepare
    end

    before do
      allow_any_instance_of(subject).to receive(:client).and_return(client)
    end

    it 'calls create on the FHIR client' do
      expect(client).to receive(:create).with(data).exactly(1).time

      subject.build(session_store).create(questionnaire_response, user)
    end

    it 'has request headers' do
      request_headers =
        { 'Authorization' => 'Bearer 123abc', 'Content-Type' => 'application/fhir+json' }

      allow(client).to receive(:create).with(data).and_return(anything)

      map_query = subject.build(session_store)
      map_query.create(questionnaire_response, user)

      expect(map_query.headers).to eq(request_headers)
    end
  end

  describe '#search_options' do
    let(:options) { { search: { parameters: { author: 'abc' } } } }

    it 'builds options' do
      expect(subject.new(session_store).search_options(author: 'abc')).to eq(options)
    end
  end

  describe '#get' do
    context 'with valid id' do
      let(:client) { double('HealthQuest::Lighthouse::FHIRClient') }
      let(:id) { 'faae134c-9c7b-49d7-8161-10e314da4de1' }

      before do
        allow_any_instance_of(subject).to receive(:client).and_return(client)
      end

      it 'returns an instance of Reply' do
        expect(client).to receive(:read).with(FHIR::QuestionnaireResponse, id).exactly(1).time

        subject.build(session_store).get(id)
      end

      it 'has request headers' do
        allow(client).to receive(:read).with(FHIR::QuestionnaireResponse, id).and_return(anything)

        map_query = subject.build(session_store)
        map_query.get(id)

        expect(map_query.headers).to eq({ 'Authorization' => 'Bearer 123abc' })
      end
    end
  end
end
