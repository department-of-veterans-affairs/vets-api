# frozen_string_literal: true

require 'rails_helper'

module AskVAApi
  module Categories
    RSpec.describe Retriever do
      let(:mock_data) do
        '{ "Topics": [{"id": 1, "name": "Category 1", "parentId": null},' \
          '{"id": 2, "name": "Category 2", "parentId": 1}]}'
      end
      let(:parsed_data) { [{ id: 1, name: 'Category 1', parentId: nil }] }
      let(:static_data_service) { instance_double(Crm::StaticData) }

      describe '#call' do
        context 'when using mock data' do
          subject(:retriever) { described_class.new(user_mock_data: true) }
          it 'reads from a file and returns an array of Entity instances' do
            expect(retriever.call).to all(be_a(Entity))
          end
        end

        context 'when not using mock data' do
          subject(:retriever) { described_class.new(user_mock_data: false) }

          before do
            allow(Crm::StaticData).to receive(:new).and_return(static_data_service)
            allow(static_data_service).to receive(:call).and_return(mock_data)
          end

          it 'fetches data using Crm::StaticData service and returns an array of Entity instances' do
            expect(retriever.call).to all(be_a(Entity))
          end
        end

        context 'when an error occurs during data retrieval' do
          subject(:retriever) { described_class.new }

          before do
            allow(Crm::StaticData).to receive(:new).and_return(static_data_service)
            allow(static_data_service).to receive(:call).and_raise(StandardError)
            allow(ErrorHandler).to receive(:handle_service_error)
          end

          it 'rescues the error and calls the ErrorHandler' do
            expect { retriever.call }.not_to raise_error
            expect(ErrorHandler).to have_received(:handle_service_error).with(instance_of(StandardError))
          end
        end

        context 'when JSON parsing fails' do
          subject(:retriever) { described_class.new }

          before do
            allow(Crm::StaticData).to receive(:new).and_return(static_data_service)
            allow(static_data_service).to receive(:call).and_return('invalid json')
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
end
