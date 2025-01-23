# frozen_string_literal: true

require 'rails_helper'

module AskVAApi
  module Contents
    RSpec.describe Retriever do
      let(:parsed_data) { { Topics: [{ Id: 1, Name: 'Category 1', ParentId: nil }] } }
      let(:static_data_service) { instance_double(Crm::CacheData) }
      let(:entity_class) { Entity }

      describe '#call' do
        let(:parent_id) { nil }
        let(:type) { 'category' }
        let(:retriever) { described_class.new(type:, user_mock_data:, entity_class:, parent_id:) }

        context 'when using mock data' do
          let(:user_mock_data) { true }
          let(:response) { retriever.call }
          let(:response_type) { response.map(&:topic_type) }

          context 'when type is Category' do
            it 'reads from a file and returns an array of Entity instances' do
              expect(response).to all(be_a(entity_class))
              expect(response_type.uniq).to eq(['Category'])
            end
          end

          context 'when type is Topic' do
            let(:parent_id) { '5c524deb-d864-eb11-bb24-000d3a579c45' }
            let(:type) { 'topic' }

            it 'reads from a file and returns an array of Entity instances' do
              expect(response).to all(be_a(entity_class))
              expect(response_type.uniq).to eq(['Topic'])
            end
          end

          context 'when type is SubTopic' do
            let(:parent_id) { '152b8586-e764-eb11-bb23-000d3a579c3f' }
            let(:type) { 'subtopic' }

            it 'reads from a file and returns an array of Entity instances' do
              expect(response).to all(be_a(entity_class))
              expect(response_type.uniq).to eq(['SubTopic'])
            end
          end
        end

        context 'when not using mock data' do
          let(:user_mock_data) { false }

          context 'when successful' do
            before do
              allow(Crm::CacheData).to receive(:new).and_return(static_data_service)
              allow(static_data_service).to receive(:call).and_return(user_mock_data ? 'mock data' : parsed_data)
            end

            it 'fetches data using Crm::CacheData service and returns an array of Entity instances' do
              expect(retriever.call).to all(be_a(entity_class))
            end
          end

          context 'when an error occurs during data retrieval' do
            let(:body) do
              '{"Data":null,"Message":"Data Validation: null ,"ExceptionOccurred":' \
                'true,"ExceptionMessage":"Data Validation: null","MessageId": "6dfa81bd-f04a-4f39-88c5-1422d88ed3ff"}'
            end
            let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

            before do
              allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
              allow_any_instance_of(Crm::Service).to receive(:call)
                .with(endpoint: 'Topics', payload: {}).and_return(failure)
            end

            it 'rescues the error and calls the ErrorHandler' do
              expect { retriever.call }.to raise_error(ErrorHandler::ServiceError)
            end
          end
        end
      end
    end
  end
end
