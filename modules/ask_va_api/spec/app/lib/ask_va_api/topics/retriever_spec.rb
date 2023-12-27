# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Topics::Retriever do
  subject(:retriever) { described_class.new(category_id: category.id) }

  let(:category) { AskVAApi::Categories::Entity.new({ id: 2, topic: 'All other Questions' }) }
  let(:service) { instance_double(Crm::Service) }
  let(:entity) { instance_double(AskVAApi::Topics::Entity) }
  let(:error_message) { 'Some error occurred' }

  before do
    allow(Crm::Service).to receive(:new).and_return(service)
    allow(AskVAApi::Topics::Entity).to receive(:new).and_return(entity)
    allow(service).to receive(:call)
  end

  describe '#call' do
    context 'when Crm raise an error' do
      let(:response) { instance_double(Faraday::Response, status: 400, body: 'Bad Request') }
      let(:endpoint) { AskVAApi::Topics::ENDPOINT }
      let(:error_message) { "Bad request to #{endpoint}: #{response.body}" }

      before do
        allow(service).to receive(:call)
          .with(endpoint:, payload: { category_id: category.id })
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
        .with(endpoint: 'get_topics_mock_data', payload: { category_id: category.id })
        .and_return([double])
      expect(retriever.call).to eq([entity])
    end
  end
end
