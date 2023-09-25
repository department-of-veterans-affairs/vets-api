# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::Retriever do
  subject(:retriever) { described_class.new(sec_id:) }

  let(:sec_id) { '123' }
  let(:service) { instance_double(Dynamics::Service) }
  let(:reply_creator) { instance_double(AskVAApi::Replies::ReplyCreator) }
  let(:entity) { instance_double(AskVAApi::Inquiries::Entity) }
  let(:inquiry_number) { 'A-1' }
  let(:error_message) { 'Some error occurred' }
  let(:criteria) { { inquiry_number: 'A-1' } }

  before do
    allow(Dynamics::Service).to receive(:new).and_return(service)
    allow(AskVAApi::Replies::ReplyCreator).to receive(:new).and_return(reply_creator)
    allow(reply_creator).to receive(:call).and_return(entity)
    allow(AskVAApi::Inquiries::Entity).to receive(:new).and_return(entity)
    allow(service).to receive(:call)
  end

  describe '#fetch_by_inquiry_number' do
    context 'when inquiry_number is blank' do
      let(:inquiry_number) { nil }

      it 'raises an ArgumentError' do
        expect { retriever.fetch_by_inquiry_number(inquiry_number:) }
          .to raise_error(ArgumentError, 'Invalid Inquiry Number')
      end
    end

    context 'when Dynamics raise an error' do
      let(:criteria) { { inquiry_number: 'A-1' } }
      let(:response) { instance_double(Faraday::Response, status: 400, body: 'Bad Request') }
      let(:endpoint) { AskVAApi::Inquiries::ENDPOINT }
      let(:error_message) { "Bad request to #{endpoint}: #{response.body}" }

      before do
        allow(service).to receive(:call)
          .with(endpoint:, criteria:)
          .and_raise(Dynamics::ErrorHandler::BadRequestError, error_message)
      end

      it 'raises a FetchInquiriesError' do
        expect do
          retriever.fetch_by_inquiry_number(inquiry_number: 'A-1')
        end.to raise_error(ErrorHandler::ServiceError, "Bad Request Error: #{error_message}")
      end
    end

    it 'returns an Entity object with correct data' do
      allow(service).to receive(:call)
        .with(endpoint: 'get_inquiries_mock_data', criteria: { inquiry_number: })
        .and_return([double])
      expect(retriever.fetch_by_inquiry_number(inquiry_number:)).to eq(entity)
    end
  end

  describe '#fetch_by_sec_id' do
    context 'when sec_id is blank' do
      let(:sec_id) { nil }

      it 'raises an ArgumentError' do
        expect { retriever.fetch_by_sec_id }
          .to raise_error(ArgumentError, 'Invalid SEC_ID')
      end
    end

    context 'when sec_id is present' do
      it 'returns an array of Entity objects' do
        allow(service).to receive(:call).and_return([entity])
        expect(retriever.fetch_by_sec_id).to eq([entity])
      end

      context 'when there are no inquiries' do
        it 'returns an empty array' do
          allow(service).to receive(:call).and_return([])
          expect(retriever.fetch_by_sec_id).to be_empty
        end
      end
    end
  end
end
