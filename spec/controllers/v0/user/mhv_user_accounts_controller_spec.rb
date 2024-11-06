# frozen_string_literal: true

require 'rails_helper'
require 'mhv/account_creation/service'

describe V0::User::MHVUserAccountsController, type: :controller do
  let(:user) { build(:user, :loa3, icn:) }
  let(:icn) { '10101V964144' }

  let!(:user_verification) do
    create(:idme_user_verification, idme_uuid: user.idme_uuid, user_credential_email:, user_account:)
  end
  let(:user_credential_email) { create(:user_credential_email) }
  let(:user_account) { create(:user_account, icn:) }
  let!(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:, response: terms_of_use_response) }
  let(:terms_of_use_response) { 'accepted' }

  let(:mhv_account_creator) { MHV::UserAccount::Creator.new(user_verification:) }
  let(:mhv_client) { instance_double(MHV::AccountCreation::Service) }
  let(:mhv_response) do
    {
      user_profile_id: '12345678',
      premium: true,
      champ_va: true,
      patient: true,
      sm_account_created: true,
      message: 'some-message'
    }
  end

  before do
    sign_in_as(user)
    allow(MHV::AccountCreation::Service).to receive(:new).and_return(mhv_client)

    allow(Rails.logger).to receive(:info)
  end

  describe '#show' do
    context 'when the user has an MHV account and the call is successful' do
      before do
        allow(mhv_client).to receive(:create_account).and_return(mhv_response)
      end

      it 'breaks the cache and returns the MHV account' do
        get :show

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['attributes']).to eq(mhv_response.with_indifferent_access)
        expect(mhv_client).to have_received(:create_account).with(icn:,
                                                                  email: user_credential_email.credential_email,
                                                                  tou_occurred_at: terms_of_use_agreement.created_at,
                                                                  break_cache: true)
      end
    end

    context 'when there is an error retrieving the MHV account' do
      shared_examples 'an unprocessable entity' do
        let(:expected_log_payload) { { error_message: expected_error_message } }
        let(:expected_log_message) { '[User][MHVUserAccountsController] show error' }
        let(:expected_response_body) do
          {
            errors: expected_error_message.split(',').map { |m| { detail: m.strip } }
          }.as_json
        end

        it 'returns an unprocessable entity' do
          get :show

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)).to eq(expected_response_body)
        end

        it 'logs the error' do
          get :show

          expect(Rails.logger).to have_received(:info).with(expected_log_message, expected_log_payload)
        end
      end

      context 'when there is an MHV client error' do
        let(:expected_error_message) { 'some client error' }

        before do
          allow(mhv_client).to receive(:create_account).and_raise(Common::Client::Errors::ClientError,
                                                                  expected_error_message)
        end

        it_behaves_like 'an unprocessable entity'
      end

      context 'when the user does not have an ICN' do
        let(:icn) { nil }
        let(:expected_error_message) { 'ICN must be present' }

        it_behaves_like 'an unprocessable entity'
      end

      context 'when the user does not have an email' do
        let(:user_credential_email) { nil }
        let(:expected_error_message) { 'Email must be present' }

        it_behaves_like 'an unprocessable entity'
      end

      context 'when the user does not have a terms of use agreement' do
        let(:terms_of_use_agreement) { nil }
        let(:expected_error_message) do
          "Current terms of use agreement must be present, Current terms of use agreement must be 'accepted'"
        end

        it_behaves_like 'an unprocessable entity'
      end

      context 'when the user has not accepted the terms of use agreement' do
        let(:terms_of_use_response) { 'declined' }
        let(:expected_error_message) { "Current terms of use agreement must be 'accepted'" }

        it_behaves_like 'an unprocessable entity'
      end
    end
  end
end
