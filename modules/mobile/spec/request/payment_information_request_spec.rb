# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'payment_information', type: :request do
  include JsonSchemaMatchers
  before { iam_sign_in }

  let(:user) { create(:user, :mhv) }
  let(:get_payment_info_body) do
    {
      'data' => {
        'id' => '69ad43ea-6882-5673-8552-377624da64a5',
        'type' => 'paymentInformation',
        'attributes' => {
          'accountControl' => {
            'canUpdateAddress' => true,
            'corpAvailIndicator' => true,
            'corpRecFoundIndicator' => true,
            'hasNoBdnPaymentsIndicator' => true,
            'identityIndicator' => true,
            'isCompetentIndicator' => true,
            'indexIndicator' => true,
            'noFiduciaryAssignedIndicator' => true,
            'notDeceasedIndicator' => true
          },
          'paymentAccount' => {
            'accountType' => 'Checking',
            'financialInstitutionName' => 'Comerica',
            'accountNumber' => '*********1234',
            'financialInstitutionRoutingNumber' => '042102115'
          }
        }
      }
    }
  end

  describe 'GET /mobile/v0/payment-information/benefits' do
    context 'with a valid evss response' do
      it 'matches the payment information schema' do
        VCR.use_cassette('evss/ppiu/payment_information') do
          get '/mobile/v0/payment-information/benefits', headers: iam_headers
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(get_payment_info_body)
          expect(response.body).to match_json_schema('payment_information')
        end
      end
    end

    context 'with a 403 response' do
      it 'returns a not authorized response' do
        VCR.use_cassette('evss/ppiu/forbidden') do
          get '/mobile/v0/payment-information/benefits', headers: iam_headers
          expect(response).to have_http_status(:forbidden)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end

    context 'with a 500 server error type' do
      it 'returns a service error response' do
        VCR.use_cassette('evss/ppiu/service_error') do
          get '/mobile/v0/payment-information/benefits', headers: iam_headers
          expect(response).to have_http_status(:service_unavailable)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end
  end

  describe 'PUT /mobile/v0/payment-information' do
    let(:content_type) { { 'CONTENT_TYPE' => 'application/json' } }
    let(:payment_info_request) { File.read('spec/support/ppiu/update_ppiu_request.json') }
    let(:post_payment_info_body) do
      {
        'data' => {
          'id' => '69ad43ea-6882-5673-8552-377624da64a5',
          'type' => 'paymentInformation',
          'attributes' => {
            'accountControl' => {
              'canUpdateAddress' => true,
              'corpAvailIndicator' => true,
              'corpRecFoundIndicator' => true,
              'hasNoBdnPaymentsIndicator' => true,
              'identityIndicator' => true,
              'isCompetentIndicator' => true,
              'indexIndicator' => true,
              'noFiduciaryAssignedIndicator' => true,
              'notDeceasedIndicator' => true
            },
            'paymentAccount' => {
              'accountType' => 'Checking',
              'financialInstitutionName' => 'Bank of EVSS',
              'accountNumber' => '****5678',
              'financialInstitutionRoutingNumber' => '021000021'
            }
          }
        }
      }
    end

    before do
      VCR.insert_cassette('evss/ppiu/payment_information')
    end

    after do
      VCR.eject_cassette
    end

    context 'with a valid evss response' do
      it 'matches the ppiu schema' do
        VCR.use_cassette('evss/ppiu/update_payment_information') do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: iam_headers.merge(content_type)
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(post_payment_info_body)
          expect(response.body).to match_json_schema('payment_information')
        end
      end

      context 'when the user does have an associated email address' do
        it 'calls a background job to send an email' do
          VCR.use_cassette('evss/ppiu/update_payment_information') do
            user.all_emails do |email|
              expect(DirectDepositEmailJob).to receive(:perform_async).with(email, nil)
            end

            put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                           headers: iam_headers.merge(content_type)
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

        it 'logs a message to Sentry' do
          VCR.use_cassette('evss/ppiu/update_payment_information') do
            expect_any_instance_of(User).to receive(:all_emails).and_return([])
            expect(Raven).to receive(:capture_message).once

            put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                           headers: iam_headers.merge(content_type)
            expect(response).to have_http_status(:ok)
          end
        end
      end
    end

    context 'with an invalid request payload' do
      let(:payment_info_request) do
        {
          'account_type' => 'Checking',
          'financial_institution_name' => 'Bank of Ad Hoc',
          'account_number' => '12345678'
        }.to_json
      end

      it 'returns a validation error' do
        put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                       headers: iam_headers.merge(content_type)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to match_json_schema('errors')
      end
    end

    context 'with a 403 response' do
      it 'returns a not authorized response' do
        VCR.use_cassette('evss/ppiu/update_forbidden') do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: iam_headers.merge(content_type)
          expect(response).to have_http_status(:forbidden)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end

    context 'with a 500 server error type' do
      it 'returns a service error response' do
        VCR.use_cassette('evss/ppiu/update_service_error') do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: iam_headers.merge(content_type)
          expect(response).to have_http_status(:service_unavailable)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end

    context 'with a 500 server error type pertaining to potential fraud' do
      it 'returns a service error response', :aggregate_failures do
        VCR.use_cassette('evss/ppiu/update_fraud') do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: iam_headers.merge(content_type)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to match_json_schema('evss_errors')
          expect(JSON.parse(response.body)['errors'].first['title']).to eq('Potential Fraud')
        end
      end
    end

    context 'with a 500 server error type pertaining to the account being flagged' do
      it 'returns a service error response', :aggregate_failures do
        VCR.use_cassette('evss/ppiu/update_flagged') do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: iam_headers.merge(content_type)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to match_json_schema('evss_errors')
          expect(JSON.parse(response.body)['errors'].first['title']).to eq('Account Flagged')
        end
      end
    end
  end
end
