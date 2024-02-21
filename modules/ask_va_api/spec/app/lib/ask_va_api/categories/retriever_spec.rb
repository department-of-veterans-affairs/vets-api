# frozen_string_literal: true

require 'rails_helper'

module AskVAApi
  module Categories
    RSpec.describe Retriever do
      let(:parsed_data) { { Topics: [{ Id: 1, Name: 'Category 1', ParentId: nil }] } }
      let(:static_data_service) { instance_double(Crm::CacheData) }
      let(:entity_class) { AskVAApi::Categories::Entity }

      describe '#call' do
        let(:retriever) { described_class.new(user_mock_data:, entity_class:) }

        before do
          allow(Crm::CacheData).to receive(:new).and_return(static_data_service)
          allow(static_data_service).to receive(:call).and_return(user_mock_data ? 'mock data' : parsed_data)
          allow(File).to receive(:read).and_return(parsed_data.to_json) if user_mock_data
          allow(ErrorHandler).to receive(:handle_service_error)
        end

        context 'when using mock data' do
          let(:user_mock_data) { true }

          it 'reads from a file and returns an array of Entity instances' do
            expect(retriever.call).to all(be_a(entity_class))
          end
        end

        context 'when not using mock data' do
          let(:user_mock_data) { false }

          it 'fetches data using Crm::CacheData service and returns an array of Entity instances' do
            expect(retriever.call).to all(be_a(entity_class))
          end
        end

        context 'when an error occurs during data retrieval' do
          let(:user_mock_data) { false }

          before { allow(static_data_service).to receive(:call).and_raise(StandardError) }

          it 'rescues the error and calls the ErrorHandler' do
            expect { retriever.call }.not_to raise_error
            expect(ErrorHandler).to have_received(:handle_service_error).with(instance_of(StandardError))
          end
        end
      end
    end
  end
end
