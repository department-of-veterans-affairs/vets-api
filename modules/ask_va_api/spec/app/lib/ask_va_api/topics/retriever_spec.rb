# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Topics::Retriever do
  subject(:retriever) do
    described_class.new(category_id: '75524deb-d864-eb11-bb24-000d3a579c45', user_mock_data:, entity_class:)
  end

  let(:parsed_data) { { Topics: [{ Id: 1, Name: 'Category 1', ParentId: nil }] } }
  let(:cache_data_service) { instance_double(Crm::CacheData) }
  let(:entity_class) { AskVAApi::Topics::Entity }
  let(:user_mock_data) { true }

  describe '#call' do
    context 'when using mock data' do
      it 'reads from a file and returns an array of Entity instances' do
        expect(retriever.call).to all(be_a(AskVAApi::Topics::Entity))
      end
    end

    context 'when not using mock data' do
      let(:user_mock_data) { false }

      before do
        allow(Crm::CacheData).to receive(:new).and_return(cache_data_service)
        allow(cache_data_service).to receive(:call).with(endpoint: 'Topics',
                                                         cache_key: 'categories_topics_subtopics')
                                                   .and_return(parsed_data)
      end

      it 'fetches data using Crm::CacheData service and returns an array of Entity instances' do
        expect(retriever.call).to all(be_a(AskVAApi::Topics::Entity))
      end

      context 'when an error occurs during data retrieval' do
        before do
          allow(cache_data_service).to receive(:call).with(endpoint: 'Topics',
                                                           cache_key: 'categories_topics_subtopics')
                                                     .and_raise(StandardError)
          allow(ErrorHandler).to receive(:handle_service_error)
        end

        it 'rescues the error and calls the ErrorHandler' do
          expect { retriever.call }.not_to raise_error
          expect(ErrorHandler).to have_received(:handle_service_error).with(instance_of(StandardError))
        end
      end

      context 'when JSON parsing fails' do
        before do
          allow(cache_data_service).to receive(:call).with(endpoint: 'Topics',
                                                           cache_key: 'categories_topics_subtopics')
                                                     .and_return('invalid json')
          allow(ErrorHandler).to receive(:handle_service_error).and_raise(ErrorHandler::ServiceError,
                                                                          "unexpected token at 'invalid json'")
        end

        it 'rescues the JSON::ParserError and calls the ErrorHandler' do
          expect { retriever.call }.to raise_error(ErrorHandler::ServiceError,
                                                   "unexpected token at 'invalid json'")
        end
      end
    end
  end
end
