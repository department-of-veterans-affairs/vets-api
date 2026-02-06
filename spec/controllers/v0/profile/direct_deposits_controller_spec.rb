# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::DirectDepositsController, feature: :direct_deposit,
                                                      team_owner: :vfs_authenticated_experience_backend,
                                                      type: :controller do
  let(:user) { create(:user, :loa3, icn: '1012666073V986297') }

  before do
    sign_in_as(user)
    token = 'abcdefghijklmnop'
    allow_any_instance_of(DirectDeposit::Configuration).to receive(:access_token).and_return(token)
    allow(Rails.logger).to receive(:info)
  end

  describe '#show' do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('lighthouse/direct_deposit/show/200_valid') do
          get(:show)
        end

        expect(response).to have_http_status(:ok)
      end

      it 'returns a veteran status' do
        VCR.use_cassette('lighthouse/direct_deposit/show/200_valid') do
          get(:show)
        end

        json = JSON.parse(response.body)
        veteran_status = json['data']['attributes']['veteran_status']

        expect(veteran_status).to eq('VETERAN')
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
        expect(control_info['is_edu_claim_available']).to be(true)
      end

      it 'does not return errors' do
        VCR.use_cassette('lighthouse/direct_deposit/show/200_valid') do
          get(:show)
        end

        json = JSON.parse(response.body)
        expect(json['errors']).to be_nil
      end
    end

    context 'when missing education benefits flag' do
      it 'returns a status of 200' do
        VCR.use_cassette('lighthouse/direct_deposit/show/200_missing_edu_flag') do
          get(:show)
        end

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        control_info = json['data']['attributes']['control_information']
        expect(control_info['is_edu_claim_available']).to be_nil
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
        expect(json['control_information']['is_edu_claim_available']).to be(false)
        expect(json['veteran_status']).not_to eq('VETERAN')
      end
    end

    context 'when invalid scopes are provided' do
      it 'returns a 400' do
        VCR.use_cassette('lighthouse/direct_deposit/show/errors/400_invalid_scopes') do
          get(:show)
        end

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(response).to have_http_status(:bad_request)
        expect(e['code']).to eq('direct.deposit.invalid.scopes')
      end
    end

    context 'when not authorized' do
      it 'returns a status of 401' do
        VCR.use_cassette('lighthouse/direct_deposit/show/errors/401_invalid_token') do
          get(:show)
        end

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(response).to have_http_status(:unauthorized)
        expect(e['code']).to eq('direct.deposit.invalid.token')
      end
    end

    context 'when ICN not found' do
      it 'returns a status of 404' do
        VCR.use_cassette('lighthouse/direct_deposit/show/errors/404_response') do
          get(:show)
        end

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(response).to have_http_status(:not_found)
        expect(e['code']).to eq('direct.deposit.icn.not.found')
      end
    end

    context 'when there is a gateway timeout' do
      it 'returns a status of 504' do
        VCR.use_cassette('lighthouse/direct_deposit/show/errors/504_response') do
          get(:show)
        end

        expect(response).to have_http_status(:gateway_timeout)

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(e['code']).to eq('direct.deposit.api.gateway.timeout')
      end
    end

    context 'logging for 5XX errors' do
      context 'when there is a 504 error' do
        before { allow(Rails.logger).to receive(:error) }

        it 'uses rails error logging' do
          expect(Rails.logger).to receive(:error).with(
            a_string_including('Direct Deposit API error'),
            hash_including(
              :error_class,
              :error_message,
              :user_uuid,
              :backtrace
            )
          )

          VCR.use_cassette('lighthouse/direct_deposit/show/errors/504_response') do
            get(:show)
          end

          expect(response).to have_http_status(:gateway_timeout)
        end
      end

      context 'when there is a 404 error' do
        it 'does not use rails error logging' do
          VCR.use_cassette('lighthouse/direct_deposit/show/errors/404_response') do
            get(:show)
          end

          expect(Rails.logger).not_to receive(:error)
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  describe '#update successful' do
    let(:params) do
      {
        payment_account: {
          account_number: '1234567890',
          account_type: 'CHECKING',
          routing_number: '031000503'
        },
        control_information: {
          can_update_direct_deposit: true,
          is_corp_available: true,
          is_edu_claim_available: true,
          is_corp_rec_found: true,
          has_no_bdn_payments: true,
          has_index: true,
          is_competent: true,
          has_mailing_address: true,
          has_no_fiduciary_assigned: true,
          is_not_deceased: true,
          has_payment_address: true,
          has_identity: true
        }
      }
    end

    it 'returns a status of 200' do
      VCR.use_cassette('lighthouse/direct_deposit/update/200_valid') do
        put(:update, params:)
      end

      expect(response).to have_http_status(:ok)
    end

    it 'returns a veteran status of VETERAN' do
      VCR.use_cassette('lighthouse/direct_deposit/update/200_valid') do
        put(:update, params:)
      end
      body = JSON.parse(response.body)
      expect(body['data']['attributes']['veteran_status']).to eq('VETERAN')
    end

    it 'capitalizes account type' do
      VCR.use_cassette('lighthouse/direct_deposit/update/200_valid') do
        put(:update, params:)
      end

      body = JSON.parse(response.body)
      payment_account = body['data']['attributes']['payment_account']

      expect(payment_account['account_type']).to eq('Checking')
    end

    context 'when the user does have an associated email address' do
      it 'sends an email through va notify' do
        expect(VANotifyDdEmailJob).to receive(:send_to_emails).with(
          user.all_emails
        )

        VCR.use_cassette('lighthouse/direct_deposit/update/200_valid') do
          put(:update, params:)
        end
      end
    end

    context 'when user does not have an associated email address' do
      it 'logs a message with Rails Logger' do
        VCR.use_cassette('lighthouse/direct_deposit/update/200_valid') do
          expect_any_instance_of(User).to receive(:all_emails).and_return([])
          expect(Rails.logger).to receive(:info)

          put(:update, params:)
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  describe '#update unsuccessful' do
    let(:params) do
      {
        payment_account: {
          account_type: 'CHECKING',
          routing_number: '031000503',
          account_number: '12345678'
        },
        control_information: {
          can_update_direct_deposit: true,
          is_corp_available: true,
          is_edu_claim_available: true
        }
      }
    end

    context 'when missing account type' do
      before { params[:payment_account].delete(:account_type) }

      it 'returns a validation error' do
        VCR.use_cassette('lighthouse/direct_deposit/update/400_invalid_account_type') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(e).not_to be_nil
        expect(e['title']).to eq('Bad Request')
        expect(e['code']).to eq('direct.deposit.account.type.invalid')
      end
    end

    context 'when missing account number' do
      before { params[:payment_account].delete(:account_number) }

      it 'returns a validation error' do
        VCR.use_cassette('lighthouse/direct_deposit/update/400_invalid_account_number') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(e).not_to be_nil
        expect(e['title']).to eq('Bad Request')
        expect(e['code']).to eq('direct.deposit.account.number.invalid')
      end
    end

    context 'when missing routing number' do
      before { params[:payment_account].delete(:routing_number) }

      it 'returns a validation error' do
        VCR.use_cassette('lighthouse/direct_deposit/update/400_invalid_routing_number') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(e).not_to be_nil
        expect(e['title']).to eq('Bad Request')
        expect(e['code']).to eq('direct.deposit.routing.number.invalid')
      end
    end

    context 'when fraud flag is present' do
      it 'returns a routing number fraud error' do
        VCR.use_cassette('lighthouse/direct_deposit/update/400_routing_number_fraud') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(e).not_to be_nil
        expect(e['title']).to eq('Bad Request')
        expect(e['code']).to eq('direct.deposit.routing.number.fraud')
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
        expect(e['code']).to eq('direct.deposit.account.number.fraud')
        expect(e['source']).to eq('Lighthouse Direct Deposit')
      end

      it 'returns a fraud indicator error' do
        VCR.use_cassette('lighthouse/direct_deposit/update/422_fraud_indicator') do
          put(:update, params:)
        end
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when user profile info is invalid' do
      it 'returns a day phone number error' do
        VCR.use_cassette('lighthouse/direct_deposit/update/400_invalid_day_phone_number') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(e).not_to be_nil
        expect(e['title']).to eq('Bad Request')
        expect(e['code']).to eq('direct.deposit.day.phone.number.invalid')
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
        expect(e['code']).to eq('direct.deposit.mailing.address.invalid')
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
        expect(e['code']).to eq('direct.deposit.routing.number.invalid.checksum')
        expect(e['source']).to eq('Lighthouse Direct Deposit')
      end

      it 'returns a potential fraud error from code GUIE50041' do
        VCR.use_cassette('lighthouse/direct_deposit/update/400_potential_fraud_GUIE50041') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(e).not_to be_nil
        expect(e['title']).to eq('Bad Request')
        expect(e['code']).to eq('direct.deposit.potential.fraud')
        expect(e['source']).to eq('Lighthouse Direct Deposit')
      end

      it 'returns a potential fraud error from code GUIE50022' do
        VCR.use_cassette('lighthouse/direct_deposit/update/400_potential_fraud_GUIE50022') do
          put(:update, params:)
        end

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        e = json['errors'].first

        expect(e).not_to be_nil
        expect(e['title']).to eq('Bad Request')
        expect(e['code']).to eq('direct.deposit.potential.fraud')
        expect(e['source']).to eq('Lighthouse Direct Deposit')
      end
    end

    context 'logging for 5XX errors' do
      context 'when there is a 502 error' do
        before { allow(Rails.logger).to receive(:error) }

        it 'uses rails error logging' do
          expect(Rails.logger).to receive(:error).with(
            a_string_including('Direct Deposit API error'),
            hash_including(
              :error_class,
              :error_message,
              :user_uuid,
              :backtrace
            )
          )

          VCR.use_cassette('lighthouse/direct_deposit/show/errors/502_update_response') do
            put(:update, params:)
          end

          expect(response).to have_http_status(:bad_gateway)
        end
      end

      context 'when there is a 404 error' do
        it 'does not use rails error logging' do
          VCR.use_cassette('lighthouse/direct_deposit/update/400_routing_number_fraud') do
            put(:update, params:)
          end

          expect(Rails.logger).not_to receive(:error)
          expect(response).to have_http_status(:bad_request)
        end
      end
    end
  end
end
