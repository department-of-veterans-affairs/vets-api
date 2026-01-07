# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SOB::V0::Ch33Status', type: :request do
  include SchemaMatchers

  let(:user) { create(:user, ssn: '123456789') }

  before { sign_in_as(user) }

  describe 'GET sob/v0/ch33_status' do
    context 'when claimant exists' do
      it 'returns 200 response' do
        VCR.use_cassette('sob/ch33_status/200') do
          get '/sob/v0/ch33_status'
          expect(response).to match_response_schema('sob/ch33_status')
          assert_response :success
        end
      end
    end

    context 'when no ssn present' do
      let(:user) { create(:user, ssn: nil) }

      it 'raises ParameterMissing error' do
        get '/sob/v0/ch33_status'
        expect(response).to have_http_status(:bad_request)
        message = JSON.parse(response.body)['errors'].first['detail']
        expect(message).to eq('The required parameter "SSN", is missing')
      end
    end

    context 'when claimant not found' do
      it 'converts 204 to 404 response' do
        VCR.use_cassette('sob/ch33_status/204') do
          get '/sob/v0/ch33_status'
          expect(response).to have_http_status(:not_found)
          message = JSON.parse(response.body)['errors'].first['detail']
          expect(message).to eq('Claimant not found')
        end
      end
    end

    context 'when upstream error' do
      it 'returns 500 response' do
        VCR.use_cassette('sob/ch33_status/500') do
          get '/sob/v0/ch33_status'
          expect(response).to have_http_status(:internal_server_error)
          message = JSON.parse(response.body)['errors'].first['detail']
          expect(message).to eq('Internal Server Error')
        end
      end
    end
  end
end
