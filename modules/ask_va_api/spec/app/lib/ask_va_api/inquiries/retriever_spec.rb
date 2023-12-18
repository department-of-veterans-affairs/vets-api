# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::Retriever do
  subject(:retriever) { described_class.new(icn:) }

  let(:icn) { '123' }
  let(:service) { instance_double(Crm::Service) }
  let(:correspondences) { instance_double(AskVAApi::Correspondences::Retriever) }
  let(:entity) { instance_double(AskVAApi::Inquiries::Entity) }
  let(:inquiry_number) { 'A-1' }
  let(:error_message) { 'Some error occurred' }
  let(:payload) { { inquiry_number: 'A-1' } }

  before do
    allow(Crm::Service).to receive(:new).and_return(service)
    allow(AskVAApi::Correspondences::Retriever).to receive(:new).and_return(correspondences)
    allow(correspondences).to receive(:call).and_return(entity)
    allow(AskVAApi::Inquiries::Entity).to receive(:new).and_return(entity)
    allow(service).to receive(:call)
  end

  describe '#fetch_by_inquiry_number' do
    context 'when inquiry_number is blank' do
      let(:inquiry_number) { nil }

      it 'raises an ErrorHandler::ServiceError' do
        expect { retriever.fetch_by_inquiry_number(inquiry_number:) }
          .to raise_error(ErrorHandler::ServiceError, 'ArgumentError: Invalid Inquiry Number')
      end
    end

    context 'when Crm raise an error' do
      let(:payload) { { inquiry_number: 'A-1' } }
      let(:response) { instance_double(Faraday::Response, status: 400, body: 'Bad Request') }
      let(:endpoint) { AskVAApi::Inquiries::ENDPOINT }
      let(:error_message) { "Bad request to #{endpoint}: #{response.body}" }

      before do
        allow(service).to receive(:call)
          .with(endpoint:, payload:)
          .and_raise(Crm::ErrorHandler::ServiceError, error_message)
      end

      it 'raises a FetchInquiriesError' do
        expect do
          retriever.fetch_by_inquiry_number(inquiry_number: 'A-1')
        end.to raise_error(ErrorHandler::ServiceError, "Crm::ErrorHandler::ServiceError: #{error_message}")
      end
    end

    it 'returns an Entity object with correct data' do
      allow(service).to receive(:call)
        .with(endpoint: 'get_inquiries_mock_data', payload: { inquiry_number: })
        .and_return([double])
      expect(retriever.fetch_by_inquiry_number(inquiry_number:)).to eq(entity)
    end
  end

  describe '#fetch_by_icn' do
    context 'when icn is blank' do
      let(:icn) { nil }

      it 'raises an ErrorHandler::ServiceError' do
        expect { retriever.fetch_by_icn }
          .to raise_error(ErrorHandler::ServiceError, 'ArgumentError: Invalid SEC_ID')
      end
    end

    context 'when icn is present' do
      it 'returns an array of Entity objects' do
        allow(service).to receive(:call).and_return([entity])
        expect(retriever.fetch_by_icn).to eq([entity])
      end

      context 'when there are no inquiries' do
        it 'returns an empty array' do
          allow(service).to receive(:call).and_return([])
          expect(retriever.fetch_by_icn).to be_empty
        end
      end
    end
  end
end
