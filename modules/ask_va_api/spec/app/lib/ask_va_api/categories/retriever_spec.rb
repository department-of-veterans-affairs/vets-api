# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Categories::Retriever do
  subject(:retriever) { described_class.new }

  let(:service) { instance_double(Dynamics::Service) }
  let(:entity) { instance_double(AskVAApi::Categories::Entity) }
  let(:error_message) { 'Some error occurred' }

  before do
    allow(Dynamics::Service).to receive(:new).and_return(service)
    allow(AskVAApi::Categories::Entity).to receive(:new).and_return(entity)
    allow(service).to receive(:call)
  end

  describe '#call' do
    context 'when Dynamics raise an error' do
      let(:response) { instance_double(Faraday::Response, status: 400, body: 'Bad Request') }
      let(:endpoint) { AskVAApi::Categories::ENDPOINT }
      let(:error_message) { "Bad request to #{endpoint}: #{response.body}" }

      before do
        allow(service).to receive(:call)
          .with(endpoint:)
          .and_raise(Dynamics::ErrorHandler::ServiceError, error_message)
      end

      it 'raises an Error' do
        expect do
          retriever.call
        end.to raise_error(ErrorHandler::ServiceError, "Dynamics::ErrorHandler::ServiceError: #{error_message}")
      end
    end

    it 'returns an Entity object with correct data' do
      allow(service).to receive(:call)
        .with(endpoint: 'get_categories_mock_data')
        .and_return([double])
      expect(retriever.call).to eq([entity])
    end
  end
end
