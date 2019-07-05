# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PPIU', type: :request do
  include SchemaMatchers

  before(:each) { sign_in }

  describe 'GET /v0/ppiu/payment_information' do
    context 'with a valid evss response' do
      let(:ppiu_response) { File.read('spec/support/ppiu/ppiu_response.json') }

      it 'should match the ppiu schema' do
        VCR.use_cassette('evss/ppiu/payment_information') do
          get '/v0/ppiu/payment_information'
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('payment_information')
          expect(JSON.parse(response.body)).to eq(JSON.parse(ppiu_response))
        end
      end
    end

    context 'with a 403 response' do
      it 'should return a not authorized response' do
        VCR.use_cassette('evss/ppiu/forbidden') do
          get '/v0/ppiu/payment_information'
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end
    end

    context 'with a 500 server error type' do
      it 'should return a service error response' do
        VCR.use_cassette('evss/ppiu/service_error') do
          get '/v0/ppiu/payment_information'
          expect(response).to have_http_status(:service_unavailable)
          expect(response).to match_response_schema('evss_errors')
        end
      end
    end
  end

  describe 'PUT /v0/ppiu/payment_information' do
    let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }
    let(:ppiu_response) { File.read('spec/support/ppiu/update_ppiu_response.json') }
    let(:ppiu_request) { File.read('spec/support/ppiu/update_ppiu_request.json') }

    context 'with a valid evss response' do
      it 'should match the ppiu schema' do
        VCR.use_cassette('evss/ppiu/update_payment_information') do
          put '/v0/ppiu/payment_information', params: ppiu_request, headers: headers
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('payment_information')
          expect(JSON.parse(response.body)).to eq(JSON.parse(ppiu_response))
        end
      end

      context 'when the user does have an associated email address' do
        it 'calls a background job to send an email' do
          VCR.use_cassette('evss/ppiu/update_payment_information') do
            expect(DirectDepositEmailJob).to receive(:perform_async)
            put '/v0/ppiu/payment_information', params: ppiu_request, headers: headers
          end
        end
      end

      context 'when user does not have an associated email address' do
        before do
          Settings.sentry.dsn = 'asdf'
        end
        after do
          Settings.sentry.dsn = nil
        end
        it 'should log a message to Sentry' do
          VCR.use_cassette('evss/ppiu/update_payment_information') do
            expect(Raven).to receive(:capture_message).once
            allow_any_instance_of(V0::PPIUController).to receive(:current_user_email).and_return(nil)
            put '/v0/ppiu/payment_information', params: ppiu_request, headers: headers
            expect(response).to have_http_status(:ok)
          end
        end
      end
    end

    context 'with an invalid request payload' do
      let(:ppiu_request) do
        {
          'account_type' => 'Checking',
          'financial_institution_name' => 'Bank of Ad Hoc',
          'account_number' => '12345678'
        }.to_json
      end

      it 'should return a validation error' do
        put '/v0/ppiu/payment_information', params: ppiu_request, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
      end
    end

    context 'with a 403 response' do
      it 'should return a not authorized response' do
        VCR.use_cassette('evss/ppiu/update_forbidden') do
          put '/v0/ppiu/payment_information', params: ppiu_request, headers: headers
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end
    end

    context 'with a 500 server error type' do
      it 'should return a service error response' do
        VCR.use_cassette('evss/ppiu/update_service_error') do
          put '/v0/ppiu/payment_information', params: ppiu_request, headers: headers
          expect(response).to have_http_status(:service_unavailable)
          expect(response).to match_response_schema('evss_errors')
        end
      end
    end

    context 'with a 500 server error type pertaining to potential fraud' do
      it 'should return a service error response', :aggregate_failures do
        VCR.use_cassette('evss/ppiu/update_fraud') do
          put '/v0/ppiu/payment_information', params: ppiu_request, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('evss_errors')
          expect(JSON.parse(response.body)['errors'].first['title']).to eq('Potential Fraud')
        end
      end
    end

    context 'with a 500 server error type pertaining to the account being flagged' do
      it 'should return a service error response', :aggregate_failures do
        VCR.use_cassette('evss/ppiu/update_flagged') do
          put '/v0/ppiu/payment_information', params: ppiu_request, headers: headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('evss_errors')
          expect(JSON.parse(response.body)['errors'].first['title']).to eq('Account Flagged')
        end
      end
    end
  end
end
