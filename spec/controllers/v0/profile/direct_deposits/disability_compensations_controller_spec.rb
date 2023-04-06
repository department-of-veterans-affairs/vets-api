# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::DirectDeposits::DisabilityCompensationsController, type: :controller do
  let(:user) { create(:user, :loa3, :accountable, icn: '1012666073V986297') }

  before do
    sign_in_as(user)
    token = 'abcdefghijklmnop'
    allow_any_instance_of(DirectDeposit::Configuration).to receive(:access_token).and_return(token)
  end

  describe '#show' do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('lighthouse/direct_deposit/show/200_response') do
          get(:show)
        end

        expect(response).to have_http_status(:ok)
      end

      it 'returns a payment account' do
        VCR.use_cassette('lighthouse/direct_deposit/show/200_response') do
          get(:show)
        end

        json = JSON.parse(response.body)
        payment_account = json['data']['attributes']['payment_account']

        expect(payment_account).not_to be_nil
        expect(payment_account['name']).to eq('WELLS FARGO BANK')
        expect(payment_account['account_type']).to eq('CHECKING')
        expect(payment_account['account_number']).to eq('******7890')
        expect(payment_account['routing_number']).to eq('*****0503')
      end

      it 'returns control information' do
        VCR.use_cassette('lighthouse/direct_deposit/show/200_response') do
          get(:show)
        end

        json = JSON.parse(response.body)
        control_info = json['data']['attributes']['control_information']

        expect(control_info['can_update_direct_deposit']).to be(true)
        expect(control_info['is_corp_available']).to be(true)
        expect(control_info['is_corp_rec_found']).to be(true)
        expect(control_info['has_no_bdn_payments']).to be(true)
        expect(control_info['has_identity']).to be(true)
        expect(control_info['has_index']).to be(true)
        expect(control_info['is_competent']).to be(true)
        expect(control_info['has_mailing_address']).to be(true)
        expect(control_info['has_no_fiduciary_assigned']).to be(true)
        expect(control_info['is_not_deceased']).to be(true)
        expect(control_info['has_payment_address']).to be(true)
      end

      it 'does not return errors' do
        VCR.use_cassette('lighthouse/direct_deposit/show/200_response') do
          get(:show)
        end

        json = JSON.parse(response.body)
        expect(json['errors']).to be_nil
      end
    end

    context 'when bad request' do
      # let(:user) { create(:user, :loa3, :accountable, icn: 'ABC') }

      it 'returns a status of 400' do
        VCR.use_cassette('lighthouse/direct_deposit/show/400_response') do
          get(:show)
        end

        expect(response).to have_http_status(:bad_request)
      end

      it 'does not return a payment account' do
        VCR.use_cassette('lighthouse/direct_deposit/show/400_response') do
          get(:show)
        end

        json = JSON.parse(response.body)
        expect(json['payment_account']).to be_nil
      end

      it 'does not return control_information' do
        VCR.use_cassette('lighthouse/direct_deposit/show/400_response') do
          get(:show)
        end

        json = JSON.parse(response.body)
        expect(json['control_information']).to be_nil
      end
    end

    context 'when not authorized' do
      it 'returns a status of 401' do
        VCR.use_cassette('lighthouse/direct_deposit/show/401_response') do
          get(:show)
        end

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user deceased' do
      it 'returns a status of 403' do
        VCR.use_cassette('lighthouse/direct_deposit/show/403_response') do
          get(:show)
        end

        json = JSON.parse(response.body)

        payment_account = json['data']['attributes']['payment_account']
        expect(payment_account).not_to be_nil

        control_info = json['data']['attributes']['control_information']
        expect(control_info['is_not_deceased']).to be(false)
      end
    end

    context 'when ICN not found' do
      it 'returns a status of 404' do
        VCR.use_cassette('lighthouse/direct_deposit/show/404_response') do
          get(:show)
        end

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when bad gateway' do
      it 'returns a status of 502' do
        VCR.use_cassette('lighthouse/direct_deposit/show/502_response') do
          get(:show)
        end

        expect(response).to have_http_status(:bad_gateway)
      end
    end

    context 'when lighthouse direct deposit feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:profile_lighthouse_direct_deposit, instance_of(User))
                                            .and_return(false)
      end

      it 'returns routing error' do
        VCR.use_cassette('lighthouse/direct_deposit/show/200_response') do
          get(:show)
        end

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe '#update' do
    context 'when successful' do
      it 'returns a status of 200' do
        params = {
          account_number: '1234567890',
          account_type: 'CHECKING',
          routing_number: '031000503'
        }

        VCR.use_cassette('lighthouse/direct_deposit/update/200_response') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when lighthouse direct deposit feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:profile_lighthouse_direct_deposit, instance_of(User))
                                            .and_return(false)
      end

      it 'returns routing error' do
        params = {
          account_number: '1234567890',
          account_type: 'CHECKING',
          routing_number: '031000503'
        }

        VCR.use_cassette('lighthouse/direct_deposit/update/200_response') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when missing account type' do
      let(:params) do
        {
          routing_number: '031000503',
          account_number: '12345678'
        }
      end

      it 'returns a validation error' do
        VCR.use_cassette('lighthouse/direct_deposit/update/200_response') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json['errors'][0]['title']).to eq('Account type is not included in the list')
        expect(json['errors'][1]['title']).to eq("Account type can't be blank")
      end
    end

    context 'when missing account number' do
      let(:params) do
        {
          account_type: 'CHECKING',
          routing_number: '031000503'
        }
      end

      it 'returns a validation error' do
        VCR.use_cassette('lighthouse/direct_deposit/update/200_response') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json['errors'][0]['title']).to eq("Account number can't be blank")
        expect(json['errors'][0]['detail']).to eq("account-number - can't be blank")
      end
    end

    context 'when missing routing number' do
      let(:params) do
        {
          account_type: 'CHECKING',
          account_number: '12345678'
        }
      end

      it 'returns a validation error' do
        VCR.use_cassette('lighthouse/direct_deposit/update/200_response') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json['errors'][0]['title']).to eq("Routing number can't be blank")
        expect(json['errors'][1]['title']).to eq('Routing number is invalid')
      end
    end

    context 'when unprocessable entity' do
      let(:params) do
        {
          account_type: 'CHECKING',
          account_number: '1234567890',
          routing_number: '031000503'
        }
      end

      it 'returns a validation error' do
        VCR.use_cassette('lighthouse/direct_deposit/update/400_response') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(e).not_to be_nil
        expect(e['title']).to eq('Bad Request')
        expect(e['detail']).to eq('Routing number related to potential fraud')
        expect(e['code']).to eq('cnp.payment.routing.number.fraud.message')
        expect(e['status']).to eq(400)
        expect(e['source']).to eq('Lighthouse Direct Deposit')
      end
    end

    context 'when invalid scopes are provided' do
      it 'returns a 400' do
        error_message = 'One or more scopes are not configured for the authorization server resource.'

        VCR.use_cassette('lighthouse/direct_deposit/show/400_invalid_scopes') do
          get(:show)
        end

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(response).to have_http_status(:bad_request)
        expect(e['title']).to eq('invalid_scope')
        expect(e['detail']).to eq(error_message)
        expect(e['code']).to eq('LIGHTHOUSE_DIRECT_DEPOSIT400')
        expect(e['status']).to eq(400)
        expect(e['source']).to eq('Lighthouse Direct Deposit')
      end
    end
  end
end
