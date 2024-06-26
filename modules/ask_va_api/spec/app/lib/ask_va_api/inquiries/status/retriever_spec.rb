# frozen_string_literal: true

require 'rails_helper'

module AskVAApi
  module Inquiries
    module Status
      RSpec.describe Retriever do
        subject(:retriever) do
          described_class.new(icn:, user_mock_data: nil, entity_class: Entity, inquiry_number: 'A-1')
        end
        let(:icn) { '1' }

        context 'when successful' do
          before do
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
            allow_any_instance_of(Crm::Service)
              .to receive(:call).and_return({
                                              Data: {
                                                Status: 'Reopened',
                                                InquiryLevelOfAuthentication: 'Personal'
                                              },
                                              Message: nil,
                                              ExceptionOccurred: false,
                                              ExceptionMessage: nil,
                                              MessageId: '26f5be95-87c6-47f0-9722-1abb5f1a59b5'
                                            })
          end

          context 'when ICN is given' do
            it 'returns the status of the inquiry' do
              expect(subject.call).to be_an(Entity)
            end
          end

          context 'when ICN is NOT given' do
            let(:icn) { nil }

            it 'returns the status of the inquiry' do
              expect(subject.call).to be_an(Entity)
            end
          end
        end

        context 'when not successful' do
          let(:body) do
            '{"Data":null,"Message":"Data Validation: No Inquiries found",' \
              '"ExceptionOccurred":true,' \
              '"ExceptionMessage":"Data Validation: No Inquiries found",' \
              '"MessageId":"28cda301-5977-4052-a391-9ab36d514919"}'
          end
          let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

          before do
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
            allow_any_instance_of(Crm::Service)
              .to receive(:call).and_return(failure)
          end

          it 'raise an error' do
            expect do
              subject.call
            end.to raise_error(ErrorHandler::ServiceError)
          end
        end
      end
    end
  end
end
