# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Attachments::Retriever do
  subject(:retriever) { described_class.new(id: '1') }

  describe '#call' do
    let(:service) { instance_double(Crm::Service) }
    let(:entity) { instance_double(AskVAApi::Attachments::Entity) }

    before do
      allow(Crm::Service).to receive(:new).and_return(service)
      allow(AskVAApi::Attachments::Entity).to receive(:new).and_return(entity)
    end

    context 'when successful' do
      before do
        allow(service).to receive(:call)
          .with(endpoint: 'get_attachments_mock_data', payload: { id: '1' })
          .and_return([double])
      end

      it 'returns an attachment object' do
        expect(retriever.call).to eq(entity)
      end
    end

    context 'when Crm raise an error' do
      let(:response) { instance_double(Faraday::Response, status: 400, body: 'Bad Request') }
      let(:endpoint) { AskVAApi::Attachments::ENDPOINT }
      let(:error_message) { "Bad request to #{endpoint}: #{response.body}" }

      before do
        allow(service).to receive(:call)
          .with(endpoint: 'get_attachments_mock_data', payload: { id: '1' })
          .and_raise(Crm::ErrorHandler::ServiceError, error_message)
      end

      it 'raises an Error' do
        expect do
          retriever.call
        end.to raise_error(ErrorHandler::ServiceError, "Crm::ErrorHandler::ServiceError: #{error_message}")
      end
    end
  end
end
