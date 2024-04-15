# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Correspondences::Retriever do
  subject(:retriever) do
    described_class.new(inquiry_id:, user_mock_data:, entity_class: AskVAApi::Correspondences::Entity)
  end

  let(:service) { instance_double(Crm::Service) }
  let(:inquiry_id) { 'A-1' }
  let(:error_message) { 'Some error occurred' }
  let(:user_mock_data) { false }

  before do
    allow(Crm::Service).to receive(:new).and_return(service)
    allow(service).to receive(:call)
  end

  describe '#call' do
    context 'when id is blank' do
      let(:inquiry_id) { nil }

      it 'raises an ArgumentError' do
        expect { retriever.call }
          .to raise_error(ErrorHandler::ServiceError, 'ArgumentError: Invalid Inquiry ID')
      end
    end

    context 'when Crm raise an error' do
      let(:endpoint) { 'inquiries/1/replies' }
      let(:response) do
        { Data: [],
          Message: 'Data Validation: No Inquiry Found',
          ExceptionOccurred: true,
          ExceptionMessage: 'Data Validation: No Inquiry Found',
          MessageId: '2d746074-9e5c-4987-a894-e3f834b156b5' }
      end

      before do
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
        allow(service).to receive(:call).and_return(response)
      end

      it 'raise CorrespondenceRetrieverError' do
        expect { retriever.call }.to raise_error(ErrorHandler::ServiceError)
      end
    end

    context 'when successful' do
      let(:user_mock_data) { true }

      it 'returns an array object with correct data' do
        expect(retriever.call.first).to be_a(AskVAApi::Correspondences::Entity)
      end
    end
  end
end
