# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::PaymentInformation::Benefits', type: :request do
  include JsonSchemaMatchers
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:get_payment_info_body) do
    {
      'data' => {
        'id' => user.uuid,
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
            'notDeceasedIndicator' => true,
            'canUpdatePayment' => true
          },
          'paymentAccount' => {
            'accountType' => 'Checking',
            'financialInstitutionName' => 'WELLS FARGO BANK',
            'accountNumber' => '******7890',
            'financialInstitutionRoutingNumber' => '031000503'
          }
        }
      }
    }
  end
  let!(:user) { sis_user(icn: '1012666073V986297', sign_in: { service_name: SAML::User::IDME_CSID }) }

  before do
    Settings.mobile_lighthouse.rsa_key = rsa_key.to_s
    Settings.lighthouse.direct_deposit.use_mocks = true
  end

  describe 'GET /mobile/v0/payment-information/benefits' do
    context 'user without access' do
      let!(:user) { sis_user(:api_auth, :loa1) }

      it 'returns 403' do
        get '/mobile/v0/payment-information/benefits', headers: sis_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with a valid response' do
      it 'matches the payment information schema' do
        VCR.use_cassette('lighthouse/direct_deposit/show/200_valid') do
          get '/mobile/v0/payment-information/benefits', headers: sis_headers
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(get_payment_info_body)
          expect(response.body).to match_json_schema('payment_information')
        end
      end
    end

    context 'with a 403 response' do
      it 'returns a not authorized response' do
        VCR.use_cassette('mobile/direct_deposit/show/403_forbidden') do
          get '/mobile/v0/payment-information/benefits', headers: sis_headers
          expect(response).to have_http_status(:forbidden)
          expect(response.body).to match_json_schema('lighthouse_errors')
        end
      end
    end

    context 'when response body is missing control_information or payment_account' do
      it 'returns not found' do
        # stubbing instead of creating a new cassette because this is not a real use case supported by
        # the lighthouse api. We've talked to lighthouse about it and hope they'll fix it in the future.
        allow_any_instance_of(Lighthouse::DirectDeposit::Response).to receive(:control_information).and_return(nil)
        allow_any_instance_of(Lighthouse::DirectDeposit::Response).to receive(:payment_account).and_return(nil)

        VCR.use_cassette('lighthouse/direct_deposit/show/200_valid') do
          get '/mobile/v0/payment-information/benefits', headers: sis_headers
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.parsed_body).to eq(
            {
              'errors' => [
                {
                  'title' => 'Unprocessable Entity',
                  'detail' => "Control information missing for user #{user.uuid}. \
Payment account info missing for user #{user.uuid}",
                  'code' => '422',
                  'status' => '422'
                }
              ]
            }
          )
        end
      end
    end

    context 'with a 500 server error type' do
      it 'returns a service error response' do
        VCR.use_cassette('lighthouse/direct_deposit/show/errors/400_unspecified_error') do
          get '/mobile/v0/payment-information/benefits', headers: sis_headers
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to match_json_schema('lighthouse_errors')
        end
      end
    end

    context 'with a user who is not authorized to update payment information' do
      let(:get_payment_info_body) do
        {
          'data' => {
            'id' => user.uuid,
            'type' => 'paymentInformation',
            'attributes' => {
              'accountControl' => {
                'canUpdateAddress' => false,
                'corpAvailIndicator' => true,
                'corpRecFoundIndicator' => true,
                'hasNoBdnPaymentsIndicator' => true,
                'identityIndicator' => true,
                'isCompetentIndicator' => true,
                'indexIndicator' => true,
                'noFiduciaryAssignedIndicator' => true,
                'notDeceasedIndicator' => true,
                'canUpdatePayment' => false
              },
              'paymentAccount' => {
                'accountType' => 'Checking',
                'financialInstitutionName' => 'WELLS FARGO BANK',
                'accountNumber' => '******7890',
                'financialInstitutionRoutingNumber' => '031000503'
              }
            }
          }
        }
      end

      it 'has canUpdatePayment as false' do
        VCR.use_cassette('lighthouse/direct_deposit/show/200_has_restrictions') do
          get '/mobile/v0/payment-information/benefits', headers: sis_headers
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(get_payment_info_body)
          expect(response.body).to match_json_schema('payment_information')
        end
      end
    end

    context 'with a non idme user' do
      let!(:user) { sis_user(icn: '1012666073V986297', sign_in: { service_name: 'iam_ssoe' }) }

      it 'returns forbidden' do
        get '/mobile/v0/payment-information/benefits', headers: sis_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PUT /mobile/v0/payment-information' do
    let(:payment_info_request) do
      {
        account_type: 'Checking',
        financial_institution_name: 'Bank of Ad Hoc',
        account_number: '12345678',
        financial_institution_routing_number: '021000021'
      }.to_json
    end
    let(:post_payment_info_body) do
      {
        'data' => {
          'id' => user.uuid,
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
              'notDeceasedIndicator' => true,
              'canUpdatePayment' => true
            },
            'paymentAccount' => {
              'accountType' => 'Checking',
              'financialInstitutionName' => 'WELLS FARGO BANK',
              'accountNumber' => '******7890',
              'financialInstitutionRoutingNumber' => '031000503'
            }
          }
        }
      }
    end

    context 'user without access' do
      let!(:user) { sis_user(:api_auth, :loa1) }

      it 'returns 403' do
        put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                       headers: sis_headers(json: true)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with a valid response' do
      it 'matches the payment_information schema' do
        VCR.use_cassette('lighthouse/direct_deposit/update/200_valid') do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: sis_headers(json: true)
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(post_payment_info_body)
          expect(response.body).to match_json_schema('payment_information')
        end
      end
    end

    context 'when the user does have an associated email address' do
      subject do
        VCR.use_cassette('lighthouse/direct_deposit/update/200_valid') do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request, headers: sis_headers(json: true)
        end
      end

      it 'calls VA Notify background job to send an email' do
        user.all_emails.each do |email|
          expect(VANotifyDdEmailJob).to receive(:perform_async).with(email)
        end

        subject
      end
    end

    context 'when user does not have an associated email address' do
      it 'logs a message with Rails Logger' do
        VCR.use_cassette('lighthouse/direct_deposit/update/200_valid') do
          expect_any_instance_of(User).to receive(:all_emails).and_return([])
          expect(Rails.logger).to receive(:info).once

          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: sis_headers(json: true)
          expect(response).to have_http_status(:ok)
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
        VCR.use_cassette('lighthouse/direct_deposit/update/400_invalid_account_number') do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: sis_headers(json: true)
        end
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with a 403 response' do
      it 'returns a not authorized response' do
        VCR.use_cassette('mobile/direct_deposit/update/403_forbidden') do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: sis_headers(json: true)
          expect(response).to have_http_status(:forbidden)
          expect(response.body).to match_json_schema('lighthouse_errors')
        end
      end
    end

    context 'with a 500 server error type' do
      it 'returns a service error response' do
        VCR.use_cassette('lighthouse/direct_deposit/update/400_unspecified_error') do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: sis_headers(json: true)
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to match_json_schema('lighthouse_errors')
        end
      end
    end

    context 'with a 500 server error type pertaining to potential fraud' do
      it 'returns a service error response', :aggregate_failures do
        VCR.use_cassette('lighthouse/direct_deposit/update/400_account_number_fraud') do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: sis_headers(json: true)
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to match_json_schema('lighthouse_errors')
        end
      end
    end

    context 'with a 500 server error type pertaining to the account being flagged' do
      it 'returns a service error response', :aggregate_failures do
        VCR.use_cassette('lighthouse/direct_deposit/update/400_unspecified_error') do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: sis_headers(json: true)
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to match_json_schema('lighthouse_errors')
        end
      end
    end

    context 'with a 400 error pertaining to routing number' do
      it 'returns a routing number checksum error converted to a 500' do
        VCR.use_cassette('lighthouse/direct_deposit/update/400_routing_number_checksum') do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: sis_headers(json: true)
        end

        expect(response).to have_http_status(:internal_server_error)
        expect(response.body).to match_json_schema('lighthouse_errors')

        meta_error = response.parsed_body.dig('errors', 0, 'meta', 'messages', 0)
        expect(meta_error['key']).to match('payment.accountRoutingNumber.invalidCheckSum')
        expect(meta_error['text']).to match('Financial institution routing number is invalid')
      end
    end

    context 'when the upstream times out' do
      it 'returns 504' do
        allow_any_instance_of(Faraday::Connection).to receive(:put).and_raise(Faraday::TimeoutError)
        put '/mobile/v0/payment-information/benefits', params: payment_info_request, headers: sis_headers(json: true)
        expect(response).to have_http_status(:gateway_timeout)
      end
    end
  end
end
