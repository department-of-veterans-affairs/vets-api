# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Profile::TelephoneValidation', type: :request do
  let(:valid_telephone) do
    {
      telephone: {
        internationalIndicator: false,
        phoneType: 'HOME',
        countryCode: '1',
        areaCode: '703',
        phoneNumber: '4531234',
        phoneNumberExt: '123'
      }
    }
  end

  let(:valid_response_body) do
    {
      'messages' => [
        {
          'code' => 'string',
          'key' => 'string',
          'text' => 'string',
          'severity' => 'INFO',
          'potentiallySelfCorrectingOnRetry' => true
        }
      ],
      'telephone' => {
        'internationalIndicator' => false,
        'phoneType' => 'HOME',
        'countryCode' => '1',
        'areaCode' => '703',
        'phoneNumber' => '4531234',
        'phoneNumberExt' => '123',
        'carrier' => 'string',
        'country' => 'US',
        'classification' => {
          'classificationName' => 'VOIP',
          'classificationCode' => '12345'
        }
      }
    }
  end

  let(:error_messages_body) do
    {
      'messages' => [
        {
          'code' => 'string',
          'key' => 'string',
          'text' => 'string',
          'severity' => 'INFO',
          'potentiallySelfCorrectingOnRetry' => true
        }
      ]
    }
  end

  let(:message_body) { { 'message' => 'string' } }

  describe 'POST /v0/profile/telephone_validation' do
    context 'when the upstream returns 200' do
      it 'returns the validated telephone data' do
        VCR.use_cassette('va_profile/telephone_validation/v1/200') do
          post '/v0/profile/telephone_validation', params: valid_telephone
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(valid_response_body)
        end
      end
    end

    context 'when the upstream returns 400' do
      it 'returns a bad request error with messages' do
        VCR.use_cassette('va_profile/telephone_validation/v1/400') do
          post '/v0/profile/telephone_validation', params: valid_telephone
          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)).to eq(error_messages_body)
        end
      end
    end

    context 'when the upstream returns 401' do
      it 'returns an unauthorized error' do
        VCR.use_cassette('va_profile/telephone_validation/v1/401') do
          post '/v0/profile/telephone_validation', params: valid_telephone
          expect(response).to have_http_status(:unauthorized)
          expect(JSON.parse(response.body)).to eq(message_body)
        end
      end
    end

    context 'when the upstream returns 403' do
      it 'returns a forbidden error' do
        VCR.use_cassette('va_profile/telephone_validation/v1/403') do
          post '/v0/profile/telephone_validation', params: valid_telephone
          expect(response).to have_http_status(:forbidden)
          expect(JSON.parse(response.body)).to eq(message_body)
        end
      end
    end

    context 'when the upstream returns 404' do
      it 'returns a not found error with messages' do
        VCR.use_cassette('va_profile/telephone_validation/v1/404') do
          post '/v0/profile/telephone_validation', params: valid_telephone
          expect(response).to have_http_status(:not_found)
          expect(JSON.parse(response.body)).to eq(error_messages_body)
        end
      end
    end

    context 'when the upstream returns 413' do
      it 'returns a payload too large error' do
        VCR.use_cassette('va_profile/telephone_validation/v1/413') do
          post '/v0/profile/telephone_validation', params: valid_telephone
          expect(response).to have_http_status(:payload_too_large)
          expect(JSON.parse(response.body)).to eq(message_body)
        end
      end
    end

    context 'when the upstream returns 429' do
      it 'returns a too many requests error' do
        VCR.use_cassette('va_profile/telephone_validation/v1/429') do
          post '/v0/profile/telephone_validation', params: valid_telephone
          expect(response).to have_http_status(:too_many_requests)
          expect(JSON.parse(response.body)).to eq(error_messages_body)
        end
      end
    end

    context 'when the upstream fails to respond' do
      it 'returns a bad gateway error' do
        VCR.use_cassette('va_profile/telephone_validation/v1/502') do
          post '/v0/profile/telephone_validation', params: valid_telephone
          expect(response).to have_http_status(:bad_gateway)
        end
      end
    end
  end
end