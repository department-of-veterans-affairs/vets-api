# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Correspondences::Retriever do
  subject(:retriever) { described_class.new(inquiry_number:) }

  let(:sec_id) { '123' }
  let(:service) { instance_double(Crm::Service) }
  let(:entity) { instance_double(AskVAApi::Correspondences::Entity) }
  let(:inquiry_number) { 'A-1' }
  let(:error_message) { 'Some error occurred' }
  let(:payload) { { inquiry_number: 'A-1' } }

  before do
    allow(Crm::Service).to receive(:new).and_return(service)
    allow(AskVAApi::Correspondences::Entity).to receive(:new).and_return(entity)
    allow(service).to receive(:call)
  end

  describe '#call' do
    context 'when inquiry_number is blank' do
      let(:inquiry_number) { nil }

      it 'raises an ArgumentError' do
        expect { retriever.call }
          .to raise_error(ErrorHandler::ServiceError, 'ArgumentError: Invalid Inquiry Number')
      end
    end

    context 'when Crm raise an error' do
      let(:payload) { { inquiry_number: 'A-1' } }
      let(:response) { instance_double(Faraday::Response, status: 400, body: 'Bad Request') }
      let(:endpoint) { AskVAApi::Correspondences::ENDPOINT }
      let(:error_message) { "Bad request to #{endpoint}: #{response.body}" }

      before do
        allow(service).to receive(:call)
          .with(endpoint:, payload:)
          .and_raise(Crm::ErrorHandler::ServiceError, error_message)
      end

      it 'raises an Error' do
        expect do
          retriever.call
        end.to raise_error(ErrorHandler::ServiceError, "Crm::ErrorHandler::ServiceError: #{error_message}")
      end
    end

    it 'returns an Entity object with correct data' do
      allow(service).to receive(:call)
        .with(endpoint: 'get_replies_mock_data', payload: { inquiry_number: })
        .and_return([double])
      expect(retriever.call).to eq(entity)
    end
  end
end
