# frozen_string_literal: true

require 'rails_helper'

module AskVAApi
  module Announcements
    RSpec.describe Retriever do
      let(:entity_class) { Entity }

      describe '#call' do
        context 'with user_mock_data' do
          let(:retriever) { described_class.new(entity_class:, user_mock_data: nil) }
          let(:service) { instance_double(Crm::Service) }

          before do
            allow(Crm::Service).to receive(:new).and_return(service)
            allow(service).to receive(:call)
              .with(endpoint: 'announcements')
              .and_return({ Data: [
                            {
                              Text: 'Test',
                              StartDate: '8/18/2024 1:00:00 PM',
                              EndDate: '8/18/2024 1:00:00 PM',
                              IsPortal: false
                            },
                            {
                              Text: 'Test announcement',
                              StartDate: '9/12/2024 12:00:00 PM',
                              EndDate: '9/12/2024 3:00:00 PM',
                              IsPortal: false
                            }
                          ] })
          end

          it 'reads from file' do
            expect(retriever.call).to all(be_a(entity_class))
          end
        end

        context 'when calling CRM announcements endpoint' do
          let(:retriever) { described_class.new(user_mock_data: false, entity_class:) }
          let(:service) { instance_double(Crm::Service) }

          before do
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
          end

          context 'when successful' do
            before do
              allow_any_instance_of(Crm::Service).to receive(:call).and_return({ Data: [{
                                                                                 Text: 'Test',
                                                                                 StartDate: '8/18/2023 1:00:00 PM',
                                                                                 EndDate: '8/18/2023 1:00:00 PM',
                                                                                 IsPortal: false
                                                                               }] })
            end

            it 'retrieve data from CRM announcements endpoint' do
              expect(retriever.call).to all(be_a(entity_class))
            end
          end

          context 'when not successful' do
            let(:body) do
              '{"Data":null,"Message"' \
                ':"Data Validation: No Announcements Posted with End Date Greater than 8/5/2024 5:49:23 PM"' \
                ',"ExceptionOccurred":true,"ExceptionMessage"' \
                ':"Data Validation: No Announcements Posted with End Date Greater than 8/5/2024 5:49:23 PM"' \
                ',"MessageId":"b8b6e029-bbea-4451-9ce1-5bd8e2b04520"}'
            end
            let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

            before do
              allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
              allow(Crm::Service).to receive(:new).and_return(service)
              allow(service).to receive(:call).and_return(failure)
            end

            it 'raise AnnouncementsRetrieverError' do
              expect { retriever.call }.to raise_error(ErrorHandler::ServiceError,
                                                       "AskVAApi::Announcements::AnnouncementsRetrieverError: #{body}")
            end
          end
        end
      end
    end
  end
end
