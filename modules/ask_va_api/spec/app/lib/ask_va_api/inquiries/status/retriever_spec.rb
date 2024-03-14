# frozen_string_literal: true

require 'rails_helper'

module AskVAApi
  module Inquiries
    module Status
      RSpec.describe Retriever do
        subject(:retriever) { described_class.new(icn: '1') }

        context 'when successful' do
          before do
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
            allow_any_instance_of(Crm::Service)
              .to receive(:call).and_return({
                                              Status: 'Reopened',
                                              Message: nil,
                                              ExceptionOccurred: false,
                                              ExceptionMessage: nil,
                                              MessageId: 'c6252e77-cf7f-48b6-96be-1b43d8e9905c'
                                            })
          end

          it 'returns the status of the inquiry' do
            expect(subject.call(inquiry_number: 'A-1')).to be_an(Entity)
          end
        end

        context 'when not successful' do
          before do
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
            allow_any_instance_of(Crm::Service)
              .to receive(:call).and_return({
                                              status: 400,
                                              body: '{"Status":null,"Message":"Data Validation: No Inquiries found",' \
                                                    '"ExceptionOccurred":true,' \
                                                    '"ExceptionMessage":"Data Validation: No Inquiries found",' \
                                                    '"MessageId":"28cda301-5977-4052-a391-9ab36d514919"}',
                                              response_headers: nil,
                                              url: nil
                                            })
          end

          it 'raise an error' do
            expect do
              subject.call(inquiry_number: 'A-1')
            end.to raise_error(AskVAApi::Inquiries::Status::Retriever::RetrievalError)
          end
        end
      end
    end
  end
end
