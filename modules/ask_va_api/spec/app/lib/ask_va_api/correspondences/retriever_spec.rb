# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Correspondences::Retriever do
  subject(:retriever) do
    described_class.new(inquiry_id:, user_mock_data:, entity_class: AskVAApi::Correspondences::Entity)
  end

  let(:service) { instance_double(Crm::Service) }
  let(:inquiry_id) { '1' }
  let(:error_message) { 'Some error occurred' }
  let(:payload) { { inquiry_id: '1' } }
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

    # context 'when Crm raise an error' do
    #   let(:payload) { { InquiryId: '1' } }
    #   let(:response) { instance_double(Faraday::Response, status: 400, body: 'Bad Request') }
    #   let(:endpoint) { 'inquiries/1/replies' }
    #   let(:error_message) { "Bad request to #{endpoint}: #{response.body}" }

    #   before do
    #     allow(service).to receive(:call)
    #       .with(endpoint:, payload:)
    #       .and_raise(Crm::ErrorHandler::ServiceError, error_message)
    #   end

    #   it 'raises an Error' do
    #     expect do
    #       retriever.call
    #     end.to raise_error(ErrorHandler::ServiceError, "Crm::ErrorHandler::ServiceError: #{error_message}")
    #   end
    # end

    context 'when successful' do
      let(:user_mock_data) { true }

      it 'returns an array object with correct data' do
        expect(retriever.call.first).to be_a(AskVAApi::Correspondences::Entity)
      end
    end
  end
end
