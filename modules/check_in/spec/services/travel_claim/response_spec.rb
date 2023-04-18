# frozen_string_literal: true

require 'rails_helper'

describe TravelClaim::Response do
  subject { described_class }

  describe '#handle' do
    context 'when status 200' do
      context 'when json string' do
        it 'returns a formatted response' do
          claims_api_response = { value: { claimNumber: 'TC202207000011666' }, formatters: [], contentTypes: [],
                                  declaredType: [], statusCode: 200 }
          resp = Faraday::Response.new(body: claims_api_response, status: 200)
          hsh = { data: claims_api_response.merge(code: 'CLM_000_SUCCESS'), status: 200 }

          expect(subject.build(response: resp).handle).to eq(hsh)
        end
      end
    end

    context 'when status 400 for already submitted claim' do
      it 'returns a formatted response' do
        error_message = '10/16/2020 : This appointment already has a claim associated with it.'
        claims_api_400_response = {
          currentDate: '[10/16/2020 03:28:48 PM]',
          message: error_message
        }
        resp = Faraday::Response.new(body: claims_api_400_response, status: 400)
        hsh = { data: { error: true, code: 'CLM_002_CLAIM_EXISTS', message: error_message }, status: resp.status }

        expect(subject.build(response: resp).handle).to eq(hsh)
      end
    end

    context 'when status 400 for multiple appointments' do
      it 'returns a formatted response' do
        error_message = '10/16/2020 : There were multiple appointments for that date'
        claims_api_400_response = {
          currentDate: '[10/16/2020 03:28:48 PM]',
          message: error_message
        }
        resp = Faraday::Response.new(body: claims_api_400_response, status: 400)
        hsh = { data: { error: true, code: 'CLM_001_MULTIPLE_APPTS', message: error_message }, status: resp.status }

        expect(subject.build(response: resp).handle).to eq(hsh)
      end
    end

    context 'when status 400 for unknown error' do
      it 'returns a formatted response' do
        error_message = '10/16/2020 : appointments not available'
        claims_api_400_response = {
          currentDate: '[10/16/2020 03:28:48 PM]',
          message: error_message
        }
        resp = Faraday::Response.new(body: claims_api_400_response, status: 400)
        hsh = { data: { error: true, code: 'CLM_010_CLAIM_SUBMISSION_ERROR', message: error_message },
                status: resp.status }

        expect(subject.build(response: resp).handle).to eq(hsh)
      end
    end

    context 'when status 401 for token error' do
      it 'returns a formatted response' do
        error_message = 'Unauthorized'
        claims_api_401_response = {
          currentDate: '[10/16/2020 03:28:48 PM]',
          message: error_message
        }
        resp = Faraday::Response.new(body: claims_api_401_response, status: 401)
        hsh = { data: { error: true, code: 'CLM_020_INVALID_AUTH', message: error_message },
                status: resp.status }

        expect(subject.build(response: resp).handle).to eq(hsh)
      end
    end

    context 'when status 404' do
      it 'returns a formatted response' do
        error_message = 'Appointment not found.'
        claims_api_response = {
          currentDate: '[10/16/2020 03:28:48 PM]',
          message: error_message
        }
        resp = Faraday::Response.new(body: claims_api_response, status: 404)
        hsh = { data: { error: true, code: 'CLM_003_APPOINTMENT_NOT_FOUND', message: error_message },
                status: resp.status }

        expect(subject.build(response: resp).handle).to eq(hsh)
      end
    end

    context 'when status 500' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: 'Something went wrong', status: 500)
        hsh = {
          data: { error: true, code: 'CLM_030_UNKNOWN_SERVER_ERROR',
                  message: 'Internal server error' }, status: resp.status
        }

        expect(subject.build(response: resp).handle).to eq(hsh)
      end
    end
  end
end
