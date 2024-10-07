# frozen_string_literal: true

require 'rails_helper'
require AskVAApi::Engine.root.join('spec', 'support', 'shared_contexts.rb')

RSpec.describe AskVAApi::Inquiries::Creator do
  # allow to have access to inquiry_params and translated_payload
  include_context 'shared data'

  let(:icn) { '123456' }
  let(:service) { instance_double(Crm::Service) }
  let(:creator) { described_class.new(icn:, service:) }
  let(:file_path) { 'modules/ask_va_api/config/locales/get_inquiries_mock_data.json' }
  let(:base64_encoded_file) { Base64.strict_encode64(File.read(file_path)) }
  let(:file) { "data:image/png;base64,#{base64_encoded_file}" }
  let(:endpoint) { AskVAApi::Inquiries::Creator::ENDPOINT }
  let(:translator) { instance_double(AskVAApi::Translator) }

  before do
    allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
    allow(AskVAApi::Translator).to receive(:new).with(inquiry_params:).and_return(translator)
    # translated_payload is in include_context 'shared data'
    allow(translator).to receive(:call).and_return(translated_payload)
  end

  describe '#call' do
    context 'when the API call is successful' do
      before do
        allow(service).to receive(:call).and_return({
                                                      Data: {
                                                        InquiryNumber: '530d56a8-affd-ee11-a1fe-001dd8094ff1'
                                                      },
                                                      Message: '',
                                                      ExceptionOccurred: false,
                                                      ExceptionMessage: '',
                                                      MessageId: 'b8ebd8e7-3bbf-49c5-aff0-99503e50ee27'
                                                    })
      end

      it 'assigns VeteranICN and posts data to the service' do
        # inquiry_params is in include_context 'shared data'
        response = creator.call(inquiry_params:)

        expect(service).to have_received(:call) do |params|
          expect(params[:payload][:VeteranICN]).to eq(icn)
        end

        expect(response).to eq({ InquiryNumber: '530d56a8-affd-ee11-a1fe-001dd8094ff1' })
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
        expect { creator.call(inquiry_params:) }.to raise_error(ErrorHandler::ServiceError)
      end
    end
  end
end
