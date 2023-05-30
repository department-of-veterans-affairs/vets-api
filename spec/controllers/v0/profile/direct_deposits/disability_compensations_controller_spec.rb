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

        expect(json['errors']).to be_nil
        expect(control_info['can_update_direct_deposit']).to be(true)
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
end
