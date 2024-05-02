# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::Creator do
  let(:icn) { '123456' }
  let(:service) { instance_double(Crm::Service) }
  let(:creator) { described_class.new(icn:, service:) }
  let(:payload) { { FirstName: 'Fake', YourLastName: 'Smith' } }
  let(:endpoint) { AskVAApi::Inquiries::Creator::ENDPOINT }

  before do
    allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
  end

  describe '#call' do
    context 'when the API call is successful' do
      before do
        allow(service).to receive(:call).with(endpoint:, method: :put,
                                              payload:).and_return({
                                                                     Data: {
                                                                       InquiryNumber: '530d56a8-affd-ee11' \
                                                                                      '-a1fe-001dd8094ff1'
                                                                     },
                                                                     Message: '',
                                                                     ExceptionOccurred: false,
                                                                     ExceptionMessage: '',
                                                                     MessageId: 'b8ebd8e7-3bbf-49c5' \
                                                                                '-aff0-99503e50ee27'
                                                                   })
      end

      it 'posts data to the service and returns the response' do
        expect(creator.call(payload:)).to eq({ InquiryNumber: '530d56a8-affd-ee11-a1fe-001dd8094ff1' })
      end
    end

    context 'when the API call fails' do
      let(:body) do
        '{"Data":null,"Message":"Data Validation: missing InquiryCategory"' \
          ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: missing' \
          'InquiryCategory","MessageId":"cb0dd954-ef25-4e56-b0d9-41925e5a190c"}'
      end
      let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

      before do
        allow(service).to receive(:call).and_return(failure)
      end

      it 'raise InquiriesCreatorError' do
        expect { creator.call(payload:) }.to raise_error(ErrorHandler::ServiceError)
      end
    end
  end
end
