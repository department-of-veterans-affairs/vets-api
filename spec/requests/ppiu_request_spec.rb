# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PPIU' do
  include SchemaMatchers

  let(:user) { create(:user, :loa3) }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  before { sign_in(user) }

  def self.test_unauthorized(verb)
    context 'with an unauthorized user' do
      let(:user) { create(:user) }

      it 'returns 403' do
        public_send(verb, '/v0/ppiu/payment_information')
        expect(response.code).to eq('403')
      end
    end
  end

  describe 'GET /v0/ppiu/payment_information' do
    context 'with a valid evss response' do
      let(:ppiu_response) { File.read('spec/support/ppiu/ppiu_response.json') }

      it 'matches the ppiu schema' do
        VCR.use_cassette('evss/ppiu/payment_information') do
          get '/v0/ppiu/payment_information'
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('payment_information')
          expect(JSON.parse(response.body)).to eq(JSON.parse(ppiu_response))
        end
      end

      it 'matches the ppiu schema when camel-inflected' do
        ppiu_response_in_camel = File.read('spec/support/ppiu/ppiu_response_in_camel.json')
        VCR.use_cassette('evss/ppiu/payment_information') do
          get '/v0/ppiu/payment_information', headers: inflection_header
          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('payment_information')
          expect(JSON.parse(response.body)).to eq(JSON.parse(ppiu_response_in_camel))
        end
      end
    end

    test_unauthorized('get')

    context 'with a 403 response' do
      it 'returns a not authorized response' do
        VCR.use_cassette('evss/ppiu/forbidden') do
          get '/v0/ppiu/payment_information'
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end

      it 'returns a not authorized response when camel-inflected' do
        VCR.use_cassette('evss/ppiu/forbidden') do
          get '/v0/ppiu/payment_information', headers: inflection_header
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_camelized_response_schema('evss_errors', strict: false)
        end
      end
    end

    context 'with a 500 server error type' do
      it 'returns a service error response' do
        VCR.use_cassette('evss/ppiu/service_error') do
          get '/v0/ppiu/payment_information'
          expect(response).to have_http_status(:service_unavailable)
          expect(response).to match_response_schema('evss_errors')
        end
      end

      it 'returns a service error response with camel-inflection' do
        VCR.use_cassette('evss/ppiu/service_error') do
          get '/v0/ppiu/payment_information', headers: inflection_header
          expect(response).to have_http_status(:service_unavailable)
          expect(response).to match_camelized_response_schema('evss_errors')
        end
      end
    end
  end

  describe 'PUT /v0/ppiu/payment_information' do
    let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }
    let(:ppiu_response) { File.read('spec/support/ppiu/update_ppiu_response.json') }
    let(:ppiu_request) { File.read('spec/support/ppiu/update_ppiu_request.json') }

    before do
      VCR.insert_cassette('evss/ppiu/payment_information')
    end

    after do
      VCR.eject_cassette
    end

    test_unauthorized('put')

    context 'with a valid evss response' do
      it 'matches the ppiu schema' do
        VCR.use_cassette('evss/ppiu/update_payment_information') do
          put('/v0/ppiu/payment_information', params: ppiu_request, headers:)
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('payment_information')
          expect(JSON.parse(response.body)).to eq(JSON.parse(ppiu_response))
        end
      end

      it 'matches the ppiu schema with camel-inflection' do
        ppiu_request_in_camel = File.read('spec/support/ppiu/update_ppiu_request_in_camel.json')
        ppiu_response_in_camel = File.read('spec/support/ppiu/update_ppiu_response_in_camel.json')
        VCR.use_cassette('evss/ppiu/update_payment_information') do
          put '/v0/ppiu/payment_information', params: ppiu_request_in_camel, headers: headers.merge(inflection_header)
          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('payment_information')
          expect(JSON.parse(response.body)).to eq(JSON.parse(ppiu_response_in_camel))
        end
      end

      context 'when the user does have an associated email address' do
        subject do
          VCR.use_cassette('evss/ppiu/update_payment_information') do
            put '/v0/ppiu/payment_information', params: ppiu_request, headers:
          end
        end

        it 'sends an email through va notify' do
          expect(VANotifyDdEmailJob).to receive(:send_to_emails).with(
            user.all_emails, :comp_pen
          )

          subject
        end
      end

      context 'when user does not have an associated email address' do
        before do
          allow(Settings.sentry).to receive(:dsn).and_return('asdf')
        end

        it 'logs a message to Sentry' do
          VCR.use_cassette('evss/ppiu/update_payment_information') do
            expect_any_instance_of(User).to receive(:all_emails).and_return([])
            expect(Raven).to receive(:capture_message).once

            put('/v0/ppiu/payment_information', params: ppiu_request, headers:)
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

      it 'returns a validation error' do
        put('/v0/ppiu/payment_information', params: ppiu_request, headers:)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
      end

      it 'returns a validation error with camel-inflection' do
        put '/v0/ppiu/payment_information', params: ppiu_request, headers: headers.merge(inflection_header)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_camelized_response_schema('errors')
      end
    end

    context 'with a 403 response' do
      it 'returns a not authorized response' do
        VCR.use_cassette('evss/ppiu/update_forbidden') do
          put('/v0/ppiu/payment_information', params: ppiu_request, headers:)
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end

      it 'returns a not authorized response with camel-inflection' do
        VCR.use_cassette('evss/ppiu/update_forbidden') do
          put '/v0/ppiu/payment_information', params: ppiu_request, headers: headers.merge(inflection_header)
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_camelized_response_schema('evss_errors', strict: false)
        end
      end
    end

    context 'with a 500 server error type' do
      it 'returns a service error response' do
        VCR.use_cassette('evss/ppiu/update_service_error') do
          put('/v0/ppiu/payment_information', params: ppiu_request, headers:)
          expect(response).to have_http_status(:service_unavailable)
          expect(response).to match_response_schema('evss_errors')
        end
      end

      it 'returns a service error response with camel-inflection' do
        VCR.use_cassette('evss/ppiu/update_service_error') do
          put '/v0/ppiu/payment_information', params: ppiu_request, headers: headers.merge(inflection_header)
          expect(response).to have_http_status(:service_unavailable)
          expect(response).to match_camelized_response_schema('evss_errors')
        end
      end
    end

    context 'with a 500 server error type pertaining to potential fraud' do
      it 'returns a service error response', :aggregate_failures do
        VCR.use_cassette('evss/ppiu/update_fraud') do
          put('/v0/ppiu/payment_information', params: ppiu_request, headers:)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('evss_errors')
          expect(JSON.parse(response.body)['errors'].first['title']).to eq('Potential Fraud')
        end
      end

      it 'returns a service error response with camel-inflection', :aggregate_failures do
        VCR.use_cassette('evss/ppiu/update_fraud') do
          put '/v0/ppiu/payment_information', params: ppiu_request, headers: headers.merge(inflection_header)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_camelized_response_schema('evss_errors')
          expect(JSON.parse(response.body)['errors'].first['title']).to eq('Potential Fraud')
        end
      end
    end

    context 'with a 500 server error type pertaining to the account being flagged' do
      it 'returns a service error response', :aggregate_failures do
        VCR.use_cassette('evss/ppiu/update_flagged') do
          put('/v0/ppiu/payment_information', params: ppiu_request, headers:)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_response_schema('evss_errors')
          expect(JSON.parse(response.body)['errors'].first['title']).to eq('Account Flagged')
        end
      end

      it 'returns a service error response with camel-inflection', :aggregate_failures do
        VCR.use_cassette('evss/ppiu/update_flagged') do
          put '/v0/ppiu/payment_information', params: ppiu_request, headers: headers.merge(inflection_header)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to match_camelized_response_schema('evss_errors')
          expect(JSON.parse(response.body)['errors'].first['title']).to eq('Account Flagged')
        end
      end
    end
  end
end
