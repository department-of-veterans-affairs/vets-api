# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'legacy Mobile::V0::PaymentInformation::Benefits', type: :request do
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
            'financialInstitutionName' => 'Comerica',
            'accountNumber' => '*********1234',
            'financialInstitutionRoutingNumber' => '042102115'
          }
        }
      }
    }
  end
  let!(:user) { sis_user(icn: '1012666073V986297', sign_in: { service_name: SAML::User::IDME_CSID }) }

  before do
    Flipper.disable(:mobile_lighthouse_direct_deposit)
  end

  describe 'GET /mobile/v0/payment-information/benefits evss' do
    context 'user without access' do
      let!(:user) { sis_user(participant_id: nil) }

      it 'returns 403' do
        get '/mobile/v0/payment-information/benefits', headers: sis_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with a valid response' do
      it 'matches the payment information schema' do
        VCR.use_cassette('evss/ppiu/payment_information') do
          get '/mobile/v0/payment-information/benefits', headers: sis_headers
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(get_payment_info_body)
          expect(response.body).to match_json_schema('payment_information')
        end
      end
    end

    context 'with a 403 response' do
      it 'returns a not authorized response' do
        VCR.use_cassette('evss/ppiu/forbidden') do
          get '/mobile/v0/payment-information/benefits', headers: sis_headers
          expect(response).to have_http_status(:forbidden)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end

    context 'with a 500 server error type' do
      it 'returns a service error response' do
        VCR.use_cassette('evss/ppiu/service_error') do
          get '/mobile/v0/payment-information/benefits', headers: sis_headers
          expect(response).to have_http_status(:service_unavailable)
          expect(response.body).to match_json_schema('evss_errors')
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
                'canUpdateAddress' => true,
                'corpAvailIndicator' => true,
                'corpRecFoundIndicator' => true,
                'hasNoBdnPaymentsIndicator' => true,
                'identityIndicator' => true,
                'isCompetentIndicator' => false,
                'indexIndicator' => true,
                'noFiduciaryAssignedIndicator' => true,
                'notDeceasedIndicator' => true,
                'canUpdatePayment' => false
              },
              'paymentAccount' => {
                'accountType' => nil,
                'financialInstitutionName' => nil,
                'accountNumber' => nil,
                'financialInstitutionRoutingNumber' => nil
              }
            }
          }
        }
      end

      it 'has canUpdatePayment as false' do
        VCR.use_cassette('mobile/payment_information/payment_information_unauthorized_to_update') do
          get '/mobile/v0/payment-information/benefits', headers: sis_headers
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(get_payment_info_body)
          expect(response.body).to match_json_schema('payment_information')
        end
      end
    end

    context 'with a non idme user' do
      before do
        allow_any_instance_of(UserIdentity).to receive(:sign_in).and_return(service_name: 'sis_ssoe')
      end

      it 'returns forbidden' do
        get '/mobile/v0/payment-information/benefits', headers: sis_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PUT /mobile/v0/payment-information evss' do
    before do
      VCR.insert_cassette('evss/ppiu/payment_information')
    end

    after do
      VCR.eject_cassette
    end

    let(:content_type) { { 'CONTENT_TYPE' => 'application/json' } }
    let(:payment_info_request) { File.read('spec/support/ppiu/update_ppiu_request.json') }
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
              'financialInstitutionName' => 'Bank of EVSS',
              'accountNumber' => '****5678',
              'financialInstitutionRoutingNumber' => '021000021'
            }
          }
        }
      }
    end

    context 'user without access' do
      let!(:user) { sis_user(participant_id: nil) }

      it 'returns 403' do
        put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                       headers: sis_headers(content_type)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with a valid response' do
      it 'matches the ppiu schema' do
        VCR.use_cassette('evss/ppiu/update_payment_information') do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: sis_headers(content_type)
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(post_payment_info_body)
          expect(response.body).to match_json_schema('payment_information')
        end
      end
    end

    context 'when the user does have an associated email address' do
      subject do
        VCR.use_cassette('evss/ppiu/update_payment_information') do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request, headers:
        end
      end

      it 'calls VA Notify background job to send an email' do
        user.all_emails do |email|
          expect(VANotifyDdEmailJob).to receive(:perform_async).with(email, nil)
        end

        subject
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
                                                       headers: sis_headers(content_type)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with a 403 response' do
      it 'returns a not authorized response' do
        VCR.use_cassette('evss/ppiu/update_forbidden') do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: sis_headers(content_type)
          expect(response).to have_http_status(:forbidden)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end

    context 'with a 500 server error type' do
      it 'returns a service error response' do
        VCR.use_cassette('evss/ppiu/service_error') do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: sis_headers(content_type)
          expect(response).to have_http_status(:service_unavailable)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end

    context 'with a 500 server error type pertaining to potential fraud' do
      it 'returns a service error response', :aggregate_failures do
        VCR.use_cassette('evss/ppiu/update_fraud') do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: sis_headers(content_type)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end

    context 'with a 500 server error type pertaining to the account being flagged' do
      it 'returns a service error response', :aggregate_failures do
        VCR.use_cassette('evss/ppiu/update_flagged') do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: sis_headers(content_type)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to match_json_schema('evss_errors')
        end
      end
    end
  end
end
