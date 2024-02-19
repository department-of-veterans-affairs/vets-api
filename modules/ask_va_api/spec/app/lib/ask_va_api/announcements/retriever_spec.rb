# frozen_string_literal: true

require 'rails_helper'

module AskVAApi
  module Announcements
    RSpec.describe Retriever do
      let(:entity_class) { Entity }

      describe '#call' do
        context 'with user_mock_data' do
          let(:retriever) { described_class.new(user_mock_data: true, entity_class:) }

          it 'reads from file' do
            expect(retriever.call).to all(be_a(entity_class))
          end
        end

        context 'with no user_mock_data' do
          let(:retriever) { described_class.new(user_mock_data: false, entity_class:) }

          before do
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
            allow_any_instance_of(Crm::Service).to receive(:call).and_return({ Data: [{
                                                                               Text: 'Test',
                                                                               StartDate: '8/18/2023 1:00:00 PM',
                                                                               EndDate: '8/18/2023 1:00:00 PM',
                                                                               IsPortal: false
                                                                             }] })
          end

          it 'calls on Crm::CacheData' do
            expect(retriever.call).to all(be_a(entity_class))
          end
        end
      end
    end
  end
end
