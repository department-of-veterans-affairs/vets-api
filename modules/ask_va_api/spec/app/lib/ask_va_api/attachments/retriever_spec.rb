# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Attachments::Retriever do
  subject(:retriever) { described_class.new(icn: '123', id: '1', entity_class: entity, user_mock_data: false) }

  describe '#call' do
    let(:entity) { AskVAApi::Attachments::Entity }
    let(:service) { instance_double(Crm::Service) }

    context 'when successful' do
      before do
        allow(Crm::Service).to receive(:new).with(icn: '123').and_return(service)
        allow(service).to receive(:call)
          .with(endpoint: 'attachment', payload: { id: '1' })
          .and_return({ Data: {
                        FileContent: 'VUVzFBBQUFBQUFB',
                        FileName: 'AttachmenttoVA1.docx'
                      } })
      end

      it 'returns an attachment object' do
        expect(retriever.call).to be_an(entity)
      end
    end

    context 'when Crm raise an error' do
      let(:body) do
        '{"Data":null,"Message":"Data Validation: Invalid GUID, Parsing Failed",' \
          '"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: Invalid GUID,' \
          ' Parsing Failed","MessageId":"c14c61c4-a3a8-4200-8c86-bdc09c261308"}'
      end
      let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

      before do
        allow(Crm::Service).to receive(:new).with(icn: '123').and_return(service)
        allow(service).to receive(:call).with(endpoint: 'attachment', payload: { id: '1' }).and_return(failure)
      end

      it 'raise the error' do
        expect { retriever.call }.to raise_error(ErrorHandler::ServiceError)
      end
    end
  end
end
