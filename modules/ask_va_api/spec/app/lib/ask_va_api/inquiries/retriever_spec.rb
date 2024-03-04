# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::Retriever do
  subject(:retriever) { described_class.new(icn:, service:) }

  let(:icn) { YAML.load_file('./modules/ask_va_api/config/locales/constants.yml')['test_users']['test_user_228_icn'] }
  let(:service) { DynamicsMockService.new(icn:) }
  let(:correspondences) { instance_double(AskVAApi::Correspondences::Retriever) }
  let(:entity) { instance_double(AskVAApi::Inquiries::Entity) }
  let(:id) { '1' }
  let(:error_message) { 'Some error occurred' }
  let(:payload) { { id: '1' } }

  before do
    allow(AskVAApi::Correspondences::Retriever).to receive(:new).and_return(correspondences)
    allow(correspondences).to receive(:call).and_return(entity)
    allow(AskVAApi::Inquiries::Entity).to receive(:new).and_return(entity)
  end

  describe '#fetch_by_id' do
    it 'returns an Entity object with correct data' do
      expect(retriever.fetch_by_id(id:)).to eq(entity)
    end

    context 'when id is blank' do
      let(:id) { nil }

      it 'raises an ErrorHandler::ServiceError' do
        expect { retriever.fetch_by_id(id:) }
          .to raise_error(ErrorHandler::ServiceError, 'ArgumentError: Invalid ID')
      end
    end

    context 'when Crm raise an error' do
      let(:payload) { { id: 'A-1' } }
      let(:response) { instance_double(Faraday::Response, status: 400, body: 'Bad Request') }
      let(:endpoint) { AskVAApi::Inquiries::ENDPOINT }
      let(:error_message) { "Bad request to #{endpoint}: #{response.body}" }

      before do
        allow(service).to receive(:call)
          .with(endpoint:, payload:)
          .and_raise(Crm::ErrorHandler::ServiceError, error_message)
      end

      it 'raises a FetchInquiriesError' do
        expect do
          retriever.fetch_by_id(id: 'A-1')
        end.to raise_error(ErrorHandler::ServiceError, "Crm::ErrorHandler::ServiceError: #{error_message}")
      end
    end
  end

  describe '#fetch_by_icn' do
    context 'when icn is blank' do
      let(:icn) { nil }

      it 'raises an ErrorHandler::ServiceError' do
        expect { retriever.fetch_by_icn }
          .to raise_error(ErrorHandler::ServiceError, 'ArgumentError: Invalid ICN')
      end
    end

    context 'when icn is present' do
      it 'returns an array of Entity objects' do
        expect(retriever.fetch_by_icn.first).to eq(entity)
      end

      context 'when there are no inquiries' do
        it 'returns an empty array' do
          allow(service).to receive(:call).and_return({ Data: [] })
          expect(retriever.fetch_by_icn).to be_empty
        end
      end
    end
  end
end
