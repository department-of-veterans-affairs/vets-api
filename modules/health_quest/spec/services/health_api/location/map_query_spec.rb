# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::HealthApi::Location::MapQuery do
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
    it 'is a FHIR::Location class' do
      expect(subject.new(session_store).fhir_model).to eq(FHIR::Location)
    end
  end

  describe '#search_options' do
    let(:options) { { search: { parameters: { _id: '123abc' } } } }

    it 'builds options' do
      expect(subject.new(session_store).search_options(_id: '123abc')).to eq(options)
    end
  end

  describe '#search' do
    context 'with valid options' do
      let(:options) do
        {
          search: {
            parameters: { _id: '123abc' }
          }
        }
      end

      before do
        allow_any_instance_of(subject).to receive(:client).and_return(client)
      end

      it 'calls search on the FHIR client' do
        expect(client).to receive(:search).with(FHIR::Location, options).exactly(1).time

        subject.build(session_store).search(_id: '123abc')
      end
    end
  end

  describe '#get' do
    context 'with valid id' do
      let(:client) { double('HealthQuest::Lighthouse::FHIRClient') }
      let(:id) { 'I2-ABC123' }

      before do
        allow_any_instance_of(subject).to receive(:client).and_return(client)
      end

      it 'receives `read` one time exactly' do
        expect(client).to receive(:read).with(FHIR::Location, id).exactly(1).time

        subject.build(session_store).get(id)
      end

      it 'has request headers' do
        allow(client).to receive(:read).with(FHIR::Location, id).and_return(anything)

        map_query = subject.build(session_store)
        map_query.get(id)

        expect(map_query.headers).to eq({ 'Authorization' => 'Bearer 123abc' })
      end
    end
  end
end
