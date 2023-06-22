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
        VCR.use_cassette('lighthouse/direct_deposit/show/200_valid') do
          get(:show)
        end

        expect(response).to have_http_status(:ok)
      end

      it 'returns a payment account' do
        VCR.use_cassette('lighthouse/direct_deposit/show/200_valid') do
          get(:show)
        end

        json = JSON.parse(response.body)
        payment_account = json['data']['attributes']['payment_account']

        expect(payment_account['name']).to eq('WELLS FARGO BANK')
        expect(payment_account['account_type']).to eq('Checking')
        expect(payment_account['account_number']).to eq('******7890')
        expect(payment_account['routing_number']).to eq('*****0503')
      end

      it 'returns control information' do
        VCR.use_cassette('lighthouse/direct_deposit/show/200_valid') do
          get(:show)
        end

        json = JSON.parse(response.body)
        control_info = json['data']['attributes']['control_information']

        expect(control_info['can_update_direct_deposit']).to be(true)
      end

      it 'does not return errors' do
        VCR.use_cassette('lighthouse/direct_deposit/show/200_valid') do
          get(:show)
        end

        json = JSON.parse(response.body)
        expect(json['errors']).to be_nil
      end
    end

    context 'when has restrictions' do
      it 'control info has flags set to false' do
        VCR.use_cassette('lighthouse/direct_deposit/show/200_has_restrictions') do
          get(:show)
        end

        json = JSON.parse(response.body)['data']['attributes']
        expect(json['control_information']['can_update_direct_deposit']).to be(false)
        expect(json['control_information']['has_payment_address']).to be(false)
      end
    end

    context 'when invalid scopes are provided' do
      it 'returns a 400' do
        VCR.use_cassette('lighthouse/direct_deposit/show/400_invalid_scopes') do
          get(:show)
        end

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(response).to have_http_status(:bad_request)
        expect(e['code']).to eq('cnp.payment.invalid.scopes')
      end
    end

    context 'when not authorized' do
      it 'returns a status of 401' do
        VCR.use_cassette('lighthouse/direct_deposit/show/401_invalid_token') do
          get(:show)
        end

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(response).to have_http_status(:unauthorized)
        expect(e['code']).to eq('cnp.payment.invalid.token')
      end
    end

    context 'when ICN not found' do
      it 'returns a status of 404' do
        VCR.use_cassette('lighthouse/direct_deposit/show/404_icn_not_found') do
          get(:show)
        end

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(response).to have_http_status(:not_found)
        expect(e['code']).to eq('cnp.payment.icn.not.found')
      end
    end

    context 'when lighthouse direct deposit feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:profile_lighthouse_direct_deposit, instance_of(User))
                                            .and_return(false)
      end

      it 'returns routing error' do
        VCR.use_cassette('lighthouse/direct_deposit/show/200_valid') do
          get(:show)
        end

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe '#update' do
    context 'when successful' do
      it 'returns a status of 200' do
        params = { account_number: '1234567890', account_type: 'CHECKING', routing_number: '031000503' }

        VCR.use_cassette('lighthouse/direct_deposit/update/200_valid') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:ok)
      end

      it 'capitalizes account type' do
        params = { account_number: '1234567890', account_type: 'CHECKING', routing_number: '031000503' }

        VCR.use_cassette('lighthouse/direct_deposit/update/200_valid') do
          put(:update, params:)
        end

        body = JSON.parse(response.body)
        payment_account = body['data']['attributes']['payment_account']

        expect(payment_account['account_type']).to eq('Checking')
      end
    end

    context 'when lighthouse direct deposit feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:profile_lighthouse_direct_deposit, instance_of(User))
                                            .and_return(false)
      end

      it 'returns routing error' do
        params = { account_number: '1234567890', account_type: 'CHECKING', routing_number: '031000503' }

        VCR.use_cassette('lighthouse/direct_deposit/update/200_valid') do
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
        VCR.use_cassette('lighthouse/direct_deposit/update/400_invalid_account_type') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(e).not_to be_nil
        expect(e['title']).to eq('Bad Request')
        expect(e['code']).to eq('cnp.payment.account.type.invalid')
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
        VCR.use_cassette('lighthouse/direct_deposit/update/400_invalid_account_number') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(e).not_to be_nil
        expect(e['title']).to eq('Bad Request')
        expect(e['code']).to eq('cnp.payment.account.number.invalid')
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
        VCR.use_cassette('lighthouse/direct_deposit/update/400_invalid_routing_number') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(e).not_to be_nil
        expect(e['title']).to eq('Bad Request')
        expect(e['code']).to eq('cnp.payment.routing.number.invalid')
      end
    end

    context 'when fraud flag is present' do
      let(:params) do
        {
          account_type: 'CHECKING',
          account_number: '1234567890',
          routing_number: '031000503'
        }
      end

      it 'returns a routing number fraud error' do
        VCR.use_cassette('lighthouse/direct_deposit/update/400_routing_number_fraud') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(e).not_to be_nil
        expect(e['title']).to eq('Bad Request')
        expect(e['code']).to eq('cnp.payment.routing.number.fraud')
        expect(e['source']).to eq('Lighthouse Direct Deposit')
      end

      it 'returns an account number fraud error' do
        VCR.use_cassette('lighthouse/direct_deposit/update/400_account_number_fraud') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(e).not_to be_nil
        expect(e['title']).to eq('Bad Request')
        expect(e['code']).to eq('cnp.payment.account.number.fraud')
        expect(e['source']).to eq('Lighthouse Direct Deposit')
      end
    end

    context 'when user profile info is invalid' do
      let(:params) do
        {
          account_type: 'CHECKING',
          account_number: '1234567890',
          routing_number: '031000503'
        }
      end

      it 'returns a day phone number error' do
        VCR.use_cassette('lighthouse/direct_deposit/update/400_invalid_day_phone_number') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(e).not_to be_nil
        expect(e['title']).to eq('Bad Request')
        expect(e['code']).to eq('cnp.payment.day.phone.number.invalid')
        expect(e['source']).to eq('Lighthouse Direct Deposit')
      end

      it 'returns an mailing address error' do
        VCR.use_cassette('lighthouse/direct_deposit/update/400_invalid_mailing_address') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(e).not_to be_nil
        expect(e['title']).to eq('Bad Request')
        expect(e['code']).to eq('cnp.payment.mailing.address.invalid')
        expect(e['source']).to eq('Lighthouse Direct Deposit')
      end

      it 'returns a routing number checksum error' do
        VCR.use_cassette('lighthouse/direct_deposit/update/400_routing_number_checksum') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(e).not_to be_nil
        expect(e['title']).to eq('Bad Request')
        expect(e['code']).to eq('cnp.payment.routing.number.invalid.checksum')
        expect(e['source']).to eq('Lighthouse Direct Deposit')
      end
    end
  end
end
