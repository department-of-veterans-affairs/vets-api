# frozen_string_literal: true

require 'rails_helper'

describe TravelClaim::Response do
  subject { described_class }

  describe '#handle' do
    context 'when status 200' do
      context 'when json string' do
        it 'returns a formatted response' do
          claims_api_response = { claimNumber: 'TC202207000011666' }
          resp = Faraday::Response.new(response_body: claims_api_response, status: 200)
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
        resp = Faraday::Response.new(response_body: claims_api_400_response, status: 400)
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
        resp = Faraday::Response.new(response_body: claims_api_400_response, status: 400)
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
        resp = Faraday::Response.new(response_body: claims_api_400_response, status: 400)
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
        resp = Faraday::Response.new(response_body: claims_api_401_response, status: 401)
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
        resp = Faraday::Response.new(response_body: claims_api_response, status: 404)
        hsh = { data: { error: true, code: 'CLM_003_APPOINTMENT_NOT_FOUND', message: error_message },
                status: resp.status }

        expect(subject.build(response: resp).handle).to eq(hsh)
      end
    end

    context 'when status 408' do
      it 'returns a formatted response' do
        error_message = 'BTSSS timeout error'
        resp = Faraday::Response.new(response_body: { message: 'BTSSS timeout error' }, status: 408)
        hsh = { data: { error: true, code: 'CLM_011_CLAIM_TIMEOUT_ERROR', message: error_message },
                status: resp.status }

        expect(subject.build(response: resp).handle).to eq(hsh)
      end
    end

    context 'when status 500' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(response_body: 'Something went wrong', status: 500)
        hsh = {
          data: { error: true, code: 'CLM_030_UNKNOWN_SERVER_ERROR',
                  message: 'Internal server error' }, status: resp.status
        }

        expect(subject.build(response: resp).handle).to eq(hsh)
      end
    end
  end

  describe '#handle_claim_status_response' do
    context 'when status 200' do
      context 'when empty response' do
        it 'returns a formatted response with empty status code' do
          resp = Faraday::Response.new(response_body: [], status: 200)
          hsh = { data: { code: 'CLM_020_EMPTY_STATUS', body: [] }, status: 200 }

          expect(subject.build(response: resp).handle_claim_status_response).to eq(hsh)
        end
      end

      context 'when multiple statuses' do
        it 'returns a formatted response with multiple status code' do
          claim_status_response = [
            {
              aptDateTime: '2024-05-30T18:44:22.733Z',
              aptId: 'test-apt-id-1',
              aptSourceSystem: 'test-apt-source',
              aptSourceSystemId: 'test-apt-system-id-2',
              claimNum: 'TC202207000011666',
              claimStatus: 'approved for payment',
              claimLastModDateTime: '2024-05-30T18:44:22.733Z',
              facilityStationNum: 'test-facility-station-num-2'
            },
            {
              aptDateTime: '2024-05-30T20:44:22.733Z',
              aptId: 'test-apt-id-2',
              aptSourceSystem: 'test-apt-source-2',
              aptSourceSystemId: 'test-apt-system-id-2',
              claimNum: 'TC202207000011633',
              claimStatus: 'approved for payment',
              claimLastModDateTime: '2024-05-30T18:44:22.733Z',
              facilityStationNum: 'test-facility-station-num-2'
            }
          ]
          resp = Faraday::Response.new(response_body: claim_status_response, status: 200)
          hsh = { data: { code: 'CLM_021_MULTIPLE_STATUSES', body: claim_status_response }, status: 200 }

          expect(subject.build(response: resp).handle_claim_status_response).to eq(hsh)
        end
      end

      context 'when single status' do
        it 'returns a formatted response with success code' do
          claim_status_response = [
            {
              aptDateTime: '2024-05-30T18:44:22.733Z',
              aptId: 'test-apt-id-1',
              aptSourceSystem: 'test-apt-source',
              aptSourceSystemId: 'test-apt-system-id-2',
              claimNum: 'TC202207000011666',
              claimStatus: 'approved for payment',
              claimLastModDateTime: '2024-05-30T18:44:22.733Z',
              facilityStationNum: 'test-facility-station-num-2'
            }
          ]
          resp = Faraday::Response.new(response_body: claim_status_response, status: 200)
          hsh = { data: { code: 'CLM_000_SUCCESS', body: claim_status_response }, status: 200 }

          expect(subject.build(response: resp).handle_claim_status_response).to eq(hsh)
        end
      end
    end

    context 'when status 408' do
      it 'returns a formatted response with timeout code' do
        error_message = 'BTSSS timeout error'
        resp = Faraday::Response.new(response_body: { message: 'BTSSS timeout error' }, status: 408)
        hsh = { data: { error: true, code: 'CLM_011_CLAIM_TIMEOUT_ERROR', message: error_message },
                status: resp.status }

        expect(subject.build(response: resp).handle_claim_status_response).to eq(hsh)
      end
    end

    context 'when status 500' do
      it 'returns a formatted response with unknown error code' do
        resp = Faraday::Response.new(response_body: 'Internal server error', status: 500)
        hsh = {
          data: { error: true, code: 'CLM_030_UNKNOWN_SERVER_ERROR',
                  message: 'Internal server error' }, status: resp.status
        }

        expect(subject.build(response: resp).handle_claim_status_response).to eq(hsh)
      end
    end
  end
end
