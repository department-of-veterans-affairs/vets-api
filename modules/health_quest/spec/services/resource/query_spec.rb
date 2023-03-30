# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::Resource::Query do
  subject { described_class }

  let(:session_store) { double('SessionStore', token: '123abc') }
  let(:opts) do
    {
      session_store:,
      resource_identifier: 'questionnaire_response',
      api: Settings.hqva_mobile.lighthouse.pgd_api
    }
  end
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
      expect(subject.build(opts)).to be_an_instance_of(subject)
    end
  end

  describe 'object initialization' do
    let(:query) { subject.new(opts) }

    it 'has a attributes' do
      expect(query.respond_to?(:access_token)).to eq(true)
      expect(query.respond_to?(:api)).to eq(true)
      expect(query.respond_to?(:headers)).to eq(true)
      expect(query.respond_to?(:resource_identifier)).to eq(true)
    end
  end

  describe '#fhir_model' do
    it 'is a FHIR::QuestionnaireResponse class' do
      expect(subject.new(opts).fhir_model).to eq(FHIR::QuestionnaireResponse)
    end
  end

  describe '#api_query_path' do
    it 'returns the pgd api path' do
      expect(subject.new(opts).api_query_path).to eq('/services/pgd/v0/r4')
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

        subject.build(opts).search(author: '123')
      end
    end
  end

  describe '#create' do
    let(:user) { double('User', icn: '1008596379V859838', first_name: 'Bob', last_name: 'Smith') }
    let(:questionnaire_response) do
      {
        appointment: { id: 'abc123' },
        questionnaire: { id: '123-abc-345-def', title: 'test' },
        item: []
      }
    end
    let(:data) do
      HealthQuest::Resource::ClientModel::QuestionnaireResponse
        .manufacture(questionnaire_response, user)
        .prepare
    end

    before do
      allow_any_instance_of(subject).to receive(:client).and_return(client)
    end

    it 'calls create on the FHIR client' do
      expect(client).to receive(:create).with(data).exactly(1).time

      subject.build(opts).create(questionnaire_response, user)
    end

    it 'has request headers' do
      request_headers =
        { 'Authorization' => 'Bearer 123abc', 'Content-Type' => 'application/fhir+json' }

      allow(client).to receive(:create).with(data).and_return(anything)

      query = subject.build(opts)
      query.create(questionnaire_response, user)

      expect(query.headers).to eq(request_headers)
    end
  end

  describe '#search_options' do
    let(:options) { { search: { parameters: { author: 'abc' } } } }

    it 'builds options' do
      expect(subject.new(opts).search_options(author: 'abc')).to eq(options)
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

        subject.build(opts).get(id)
      end

      it 'has request headers' do
        allow(client).to receive(:read).with(FHIR::QuestionnaireResponse, id).and_return(anything)

        query = subject.build(opts)
        query.get(id)

        expect(query.headers).to eq({ 'Authorization' => 'Bearer 123abc' })
      end
    end
  end
end
