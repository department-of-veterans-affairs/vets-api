# frozen_string_literal: true

require 'rails_helper'

describe Eps::DraftAppointmentService::ServiceError do
  subject { described_class.new(message, status:, detail:) }

  let(:message) { 'Error message' }
  let(:status) { :bad_gateway }
  let(:detail) { 'Detailed error information' }

  describe '#initialize' do
    it 'sets message, status, and detail attributes' do
      expect(subject.message).to eq('Error message')
      expect(subject.status).to eq(:bad_gateway)
      expect(subject.detail).to eq('Detailed error information')
    end

    context 'when status is not provided' do
      let(:status) { nil }

      it 'extracts status from detail' do
        expect(subject.status).to eq(:bad_gateway)
      end

      it 'extracts a specific status code from detail if present' do
        error = described_class.new('Error message', detail: 'Error with code: "VAOS_404"')
        expect(error.status).to eq(404)
      end

      it 'extracts a specific status code from detail using alternate format' do
        error = described_class.new('Error message', detail: 'Error with :code => "VAOS_404"')
        expect(error.status).to eq(404)
      end

      it 'converts 500 to :bad_gateway' do
        error = described_class.new('Error message', detail: 'Error with code: "VAOS_500"')
        expect(error.status).to eq(:bad_gateway)
      end
    end
  end

  describe '#extract_status' do
    it 'returns :bad_gateway when error message is nil' do
      expect(subject.send(:extract_status, nil)).to eq(:bad_gateway)
    end

    it 'returns :bad_gateway when error message is not a string' do
      expect(subject.send(:extract_status, 123)).to eq(:bad_gateway)
    end

    it 'returns :bad_gateway when error message does not contain a status code' do
      expect(subject.send(:extract_status, 'Error without status code')).to eq(:bad_gateway)
    end
  end

  describe '#to_response' do
    it 'formats the error as a standardized API response hash' do
      response = subject.to_response

      expect(response).to be_a(Hash)
      expect(response[:status]).to eq(:bad_gateway)
      expect(response[:json]).to be_a(Hash)
      expect(response[:json][:errors]).to be_an(Array)
      expect(response[:json][:errors].first[:title]).to eq('Error message')
      expect(response[:json][:errors].first[:detail]).to eq('Detailed error information')
      expect(response[:json][:errors].first[:code]).to eq('Eps::DraftAppointmentService::ServiceError')
    end
  end
end
