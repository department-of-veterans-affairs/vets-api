# frozen_string_literal: true

require 'rails_helper'

module AskVAApi
  module Optionset
    RSpec.describe Retriever do
      let(:entity_class) { Entity }
      let(:name) { 'branchofservice' }
      let(:cache_data_service) { instance_double(Crm::CacheData) }

      describe '#call' do
        context 'with user_mock_data' do
          let(:retriever) { described_class.new(name:, user_mock_data: true, entity_class:) }

          it 'reads from file' do
            expect(retriever.call).to all(be_a(entity_class))
          end
        end

        context 'with no user_mock_data' do
          let(:retriever) { described_class.new(name:, user_mock_data: false, entity_class:) }

          before do
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
            allow(Crm::CacheData).to receive(:new).and_return(cache_data_service)
            allow(cache_data_service).to receive(:call).and_return({ Data: [{ Id: 722_310_000,
                                                                              Name: 'Air Force' }] })
          end

          it 'calls on Crm::CacheData' do
            expect(retriever.call).to all(be_a(entity_class))
          end
        end
      end
    end
  end
end
