# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.shared_examples 'payment information' do |lighthouse_flag|
  upstream_service = lighthouse_flag ? 'lighthouse' : 'evss'

  let(:user) { build(:iam_user) }

  before do
    iam_sign_in(user)

    if lighthouse_flag
      Flipper.enable(:mobile_lighthouse_direct_deposit, user)
    else
      Flipper.disable(:mobile_lighthouse_direct_deposit)
    end
  end

  let(:payment_information_vcr) do
    lighthouse_flag ? 'lighthouse/direct_deposit/show/200_valid' : 'evss/ppiu/payment_information'
  end

  let(:payment_information_service_error_vcr) do
    lighthouse_flag ? 'lighthouse/direct_deposit/show/400_unspecified_error' : 'evss/ppiu/service_error'
  end

  let(:payment_information_forbidden_vcr) do
    lighthouse_flag ? 'mobile/direct_deposit/show/403_forbidden' : 'evss/ppiu/forbidden'
  end

  let(:payment_information_unauthorized_vcr) do
    if lighthouse_flag
      'lighthouse/direct_deposit/show/200_has_restrictions'
    else
      'mobile/payment_information/payment_information_unauthorized_to_update'
    end
  end

  let(:payment_information_update_vcr) do
    lighthouse_flag ? 'lighthouse/direct_deposit/update/200_valid' : 'evss/ppiu/update_payment_information'
  end

  let(:payment_information_update_service_error_vcr) do
    lighthouse_flag ? 'lighthouse/direct_deposit/update/400_unspecified_error' : 'evss/ppiu/service_error'
  end

  let(:payment_information_update_forbidden_vcr) do
    lighthouse_flag ? 'mobile/direct_deposit/update/403_forbidden' : 'evss/ppiu/update_forbidden'
  end

  let(:payment_information_update_fraud_vcr) do
    lighthouse_flag ? 'lighthouse/direct_deposit/update/400_account_number_fraud' : 'evss/ppiu/update_fraud'
  end

  let(:payment_information_update_flagged_vcr) do
    lighthouse_flag ? 'lighthouse/direct_deposit/update/400_unspecified_error' : 'evss/ppiu/update_flagged'
  end

  let(:payment_information_update_validation_error_vcr) do
    lighthouse_flag ? 'lighthouse/direct_deposit/update/400_invalid_account_number' : nil
  end

  let(:errors) do
    lighthouse_flag ? 'lighthouse_errors' : 'evss_errors'
  end

  let(:get_payment_info_body) do
    if lighthouse_flag
      {
        'data' => {
          'id' => '3097e489-ad75-5746-ab1a-e0aabc1b426a',
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
              'accountType' => 'CHECKING',
              'financialInstitutionName' => 'WELLS FARGO BANK',
              'accountNumber' => '******7890',
              'financialInstitutionRoutingNumber' => '031000503'
            }
          }
        }
      }
    else
      {
        'data' => {
          'id' => '3097e489-ad75-5746-ab1a-e0aabc1b426a',
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
  end

  describe "GET /mobile/v0/payment-information/benefits #{upstream_service}" do
    context 'with a valid response' do
      it 'matches the payment information schema' do
        VCR.use_cassette(payment_information_vcr) do
          get '/mobile/v0/payment-information/benefits', headers: iam_headers
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(get_payment_info_body)
          expect(response.body).to match_json_schema('payment_information')
        end
      end
    end

    context 'with a 403 response' do
      it 'returns a not authorized response' do
        VCR.use_cassette(payment_information_forbidden_vcr) do
          get '/mobile/v0/payment-information/benefits', headers: iam_headers
          expect(response).to have_http_status(:forbidden)
          expect(response.body).to match_json_schema(errors)
        end
      end
    end

    context 'with a 500 server error type' do
      it 'returns a service error response' do
        VCR.use_cassette(payment_information_service_error_vcr) do
          get '/mobile/v0/payment-information/benefits', headers: iam_headers
          expect(response).to have_http_status(lighthouse_flag ? :bad_request : :service_unavailable)
          expect(response.body).to match_json_schema(errors)
        end
      end
    end

    context 'with a user who is not authorized to update payment information' do
      let(:get_payment_info_body) do
        if lighthouse_flag
          {
            'data' => {
              'id' => '3097e489-ad75-5746-ab1a-e0aabc1b426a',
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
                  'accountType' => 'CHECKING',
                  'financialInstitutionName' => 'WELLS FARGO BANK',
                  'accountNumber' => '******7890',
                  'financialInstitutionRoutingNumber' => '031000503'
                }
              }
            }
          }
        else
          {
            'data' => {
              'id' => '3097e489-ad75-5746-ab1a-e0aabc1b426a',
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
      end

      it 'has canUpdatePayment as false' do
        VCR.use_cassette(payment_information_unauthorized_vcr) do
          get '/mobile/v0/payment-information/benefits', headers: iam_headers
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(get_payment_info_body)
          expect(response.body).to match_json_schema('payment_information')
        end
      end
    end

    context 'with a non idme user' do
      before do
        allow_any_instance_of(UserIdentity).to receive(:sign_in).and_return(service_name: 'iam_ssoe')
      end

      it 'returns forbidden' do
        get '/mobile/v0/payment-information/benefits', headers: iam_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PUT /mobile/v0/payment-information #{upstream_service}" do
    before do
      VCR.insert_cassette('evss/ppiu/payment_information') unless lighthouse_flag
    end

    after do
      VCR.eject_cassette unless lighthouse_flag
    end

    let(:content_type) { { 'CONTENT_TYPE' => 'application/json' } }
    let(:payment_info_request) { File.read('spec/support/ppiu/update_ppiu_request.json') }
    let(:post_payment_info_body) do
      if lighthouse_flag
        {
          'data' => {
            'id' => '3097e489-ad75-5746-ab1a-e0aabc1b426a',
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
                'accountType' => 'CHECKING',
                'financialInstitutionName' => 'WELLS FARGO BANK',
                'accountNumber' => '******7890',
                'financialInstitutionRoutingNumber' => '031000503'
              }
            }
          }
        }
      else
        {
          'data' => {
            'id' => '3097e489-ad75-5746-ab1a-e0aabc1b426a',
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
    end

    context 'with a valid response' do
      it 'matches the ppiu schema' do
        allow(DirectDepositEmailJob).to receive(:send_to_emails)
        VCR.use_cassette(payment_information_update_vcr) do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: iam_headers.merge(content_type)
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(post_payment_info_body)
          expect(response.body).to match_json_schema('payment_information')
        end
      end
    end

    context 'when the user does have an associated email address' do
      subject do
        VCR.use_cassette(payment_information_update_vcr) do
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

    context 'when user does not have an associated email address' do
      before { allow(Settings.sentry).to receive(:dsn).and_return('asdf') }

      it 'logs a message to Sentry' do
        VCR.use_cassette(payment_information_update_vcr) do
          expect_any_instance_of(User).to receive(:all_emails).and_return([])
          expect(Raven).to receive(:capture_message).once

          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: iam_headers.merge(content_type)
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
        VCR.use_cassette(payment_information_update_validation_error_vcr) do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: iam_headers.merge(content_type)
        end
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with a 403 response' do
      it 'returns a not authorized response' do
        VCR.use_cassette(payment_information_update_forbidden_vcr) do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: iam_headers.merge(content_type)
          expect(response).to have_http_status(:forbidden)
          expect(response.body).to match_json_schema(errors)
        end
      end
    end

    context 'with a 500 server error type' do
      it 'returns a service error response' do
        VCR.use_cassette(payment_information_update_service_error_vcr) do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: iam_headers.merge(content_type)
          expect(response).to have_http_status(lighthouse_flag ? :bad_request : :service_unavailable)
          expect(response.body).to match_json_schema(errors)
        end
      end
    end

    context 'with a 500 server error type pertaining to potential fraud' do
      it 'returns a service error response', :aggregate_failures do
        VCR.use_cassette(payment_information_update_fraud_vcr) do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: iam_headers.merge(content_type)
          expect(response).to have_http_status(lighthouse_flag ? :bad_request : :unprocessable_entity)
          expect(response.body).to match_json_schema(errors)
        end
      end
    end

    context 'with a 500 server error type pertaining to the account being flagged' do
      it 'returns a service error response', :aggregate_failures do
        VCR.use_cassette(payment_information_update_flagged_vcr) do
          put '/mobile/v0/payment-information/benefits', params: payment_info_request,
                                                         headers: iam_headers.merge(content_type)
          expect(response).to have_http_status(lighthouse_flag ? :bad_request : :unprocessable_entity)
          expect(response.body).to match_json_schema(errors)
        end
      end
    end
  end
end

RSpec.describe 'payment_information', type: :request do
  include JsonSchemaMatchers
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }

  before do
    allow_any_instance_of(UserIdentity).to receive(:icn).and_return('1012666073V986297')
    allow_any_instance_of(UserIdentity).to receive(:sign_in).and_return(service_name: SAML::User::IDME_CSID)
    Settings.mobile_lighthouse.rsa_key = rsa_key.to_s
    Settings.lighthouse.direct_deposit.use_mocks = true
  end

  it_behaves_like 'payment information', false
  it_behaves_like 'payment information', true
end
