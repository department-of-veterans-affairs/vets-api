# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Correspondences::Retriever do
  subject(:retriever) do
    described_class.new(icn:, inquiry_id:, user_mock_data:, entity_class: AskVAApi::Correspondences::Entity)
  end

  let(:service) { instance_double(Crm::Service) }
  let(:inquiry_id) { 'A-1' }
  let(:icn) { '123' }
  let(:error_message) { 'Some error occurred' }
  let(:user_mock_data) { false }

  before do
    allow(Crm::Service).to receive(:new).and_return(service)
    allow(service).to receive(:call)
  end

  describe '#call' do
    context 'when Crm raise an error' do
      let(:endpoint) { 'inquiries/1/replies' }
      let(:body) do
        '{"Data":[],"Message":"null",' \
          '"ExceptionOccurred":false,"ExceptionMessage":"null", ' \
          '"MessageId":"95f9d1e7-d532-41d7-b43f-78ae9a3e778d"}'
      end
      let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

      before do
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
        allow(service).to receive(:call).and_return(failure)
      end

      it 'returns the error' do
        expect(retriever.call).to eq(body)
      end
    end

    context 'when successful' do
      context 'with user_mock_data' do
        let(:user_mock_data) { true }

        it 'returns an array object with correct data' do
          expect(retriever.call.first).to be_a(AskVAApi::Correspondences::Entity)
        end
      end

      context 'with Crm::Service' do
        let(:crm_response) do
          {
            Data: [
              {
                Id: 'a5247de6-62c4-ee11-907a-001dd804eab2',
                CreatedOn: '2/5/2024 8:14:48 PM',
                ModifiedOn: '2/5/2024 8:14:48 PM',
                StatusReason: 'PendingSend',
                Description: 'Dear aminul, Thank you for submitting ' \
                             'your Inquiry with the U.S.',
                MessageType: 'Notification',
                EnableReply: true,
                AttachmentNames: nil
              },
              {
                Id: 'f4b12ee3-93bb-ed11-9886-001dd806a6a7',
                ModifiedOn: '3/5/2023 8:25:49 PM',
                StatusReason: 'Sent',
                Description: 'Dear aminul, Thank you for submitting your ' \
                             'Inquiry with the U.S. Department of Veteran Affairs.',
                MessageType: 'Notification',
                EnableReply: true,
                AttachmentNames: nil
              }
            ],
            Message: nil,
            ExceptionOccurred: false,
            ExceptionMessage: nil,
            MessageId: '086594d9-188b-46b0-9ce2-b8b36329506b'
          }
        end

        before do
          allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
          allow(service).to receive(:call).and_return(crm_response)
        end

        it 'returns an array object with correct data' do
          expect(retriever.call.first).to be_a(AskVAApi::Correspondences::Entity)
        end
      end
    end
  end
end
