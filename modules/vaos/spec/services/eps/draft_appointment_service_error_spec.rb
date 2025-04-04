# frozen_string_literal: true

require 'rails_helper'

describe Eps::DraftAppointmentServiceError do
  describe '#initialize' do
    it 'sets the message and attributes' do
      error = described_class.new('Error message', status: :bad_request, detail: 'Detailed error')

      expect(error.message).to eq('Error message')
      expect(error.status).to eq(:bad_request)
      expect(error.detail).to eq('Detailed error')
    end

    it 'falls back to extract_status when status is nil' do
      error = described_class.new('Error message', detail: 'code: "VAOS_404"')

      expect(error.status).to eq(404)
    end

    it 'defaults to :bad_gateway when no status is provided or extracted' do
      error = described_class.new('Error message')

      expect(error.status).to eq(:bad_gateway)
    end
  end

  describe '#extract_status' do
    let(:error) { described_class.new('Error message') }

    it 'returns :bad_gateway when error_message is not a string' do
      expect(error.send(:extract_status, nil)).to eq(:bad_gateway)
      expect(error.send(:extract_status, 123)).to eq(:bad_gateway)
    end

    it 'extracts various status codes from error messages with VAOS_ pattern' do
      expect(error.send(:extract_status, 'Error with code: "VAOS_404"')).to eq(404)
      expect(error.send(:extract_status, 'Error with code: "VAOS_400"')).to eq(400)
      expect(error.send(:extract_status, 'Error contains code: "VAOS_403"')).to eq(403)
    end

    it 'converts 5xx status codes to :bad_gateway' do
      expect(error.send(:extract_status, 'Error with code: "VAOS_500"')).to eq(:bad_gateway)
      expect(error.send(:extract_status, 'Error with code: "VAOS_502"')).to eq(:bad_gateway)
      expect(error.send(:extract_status, 'Error with code: "VAOS_503"')).to eq(:bad_gateway)
    end

    it 'returns :bad_gateway when no status code is found' do
      expect(error.send(:extract_status, 'Some error message without a code')).to eq(:bad_gateway)
    end
  end

  describe 'handling of upstream errors' do
    context 'with VAOS backend service exceptions' do
      it 'handles 4xx error status correctly' do
        # Test with 400 status
        error = described_class.new(
          'BackendServiceException',
          detail: 'Invalid request parameters',
          status: 400
        )

        expect(error.message).to eq('BackendServiceException')
        expect(error.detail).to eq('Invalid request parameters')
        expect(error.status).to eq(400)

        # Test status extraction from VAOS exception key
        error = described_class.new('Resource not found error', detail: 'code: "VAOS_404"')
        expect(error.status).to eq(404)
      end

      it 'converts 5xx status codes to :bad_gateway' do
        error = described_class.new(
          'Upstream service error',
          detail: 'Bad Gateway',
          status: 502
        )

        expect(error.status).to eq(:bad_gateway)
      end
    end

    context 'with Redis errors' do
      it 'handles various Redis error types as :bad_gateway' do
        # Test representative Redis error types
        [
          Redis::ConnectionError.new('Error connecting to Redis'),
          Redis::TimeoutError.new('Connection timed out'),
          Redis::CommandError.new('WRONGTYPE Operation against a key')
        ].each do |redis_error|
          error = described_class.new('Redis error', detail: redis_error.message)
          expect(error.status).to eq(:bad_gateway)
          expect(error.detail).to eq(redis_error.message)
        end
      end
    end

    context 'with EPS service errors' do
      it 'extracts status from EPS error messages containing VAOS code' do
        eps_error_message = 'EPS provider service returned code: "VAOS_403"'
        error = described_class.new('EPS service error', detail: eps_error_message)

        expect(error.message).to eq('EPS service error')
        expect(error.detail).to eq(eps_error_message)
        expect(error.status).to eq(403)
      end

      it 'handles various EPS errors appropriately' do
        # 400 error
        error = described_class.new(
          'EPS provider service error',
          detail: 'Provider not found',
          status: 400
        )
        expect(error.status).to eq(400)

        # Timeout (no explicit status, defaults to :bad_gateway)
        error = described_class.new(
          'EPS request timed out',
          detail: 'Connection to EPS service timed out'
        )
        expect(error.status).to eq(:bad_gateway)
      end
    end
  end
end
