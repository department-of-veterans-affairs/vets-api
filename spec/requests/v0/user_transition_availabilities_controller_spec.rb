# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::UserTransitionAvailabilitiesController, type: :request do
  let(:user) { create(:user, :dslogon) }
  let(:user_verification) { create(:dslogon_user_verification, dslogon_uuid: user.edipi) }
  let(:user_account) { user_verification.user_account }

  before { sign_in_as(user) }

  describe '/v0/user_transition_availabilities' do
    context 'when Flipper organic_conversion_experiment is enabled' do
      let!(:user_acceptable_verified_credential) do
        create(:user_acceptable_verified_credential, :with_avc, user_account:)
      end

      it 'is a valid request' do
        get '/v0/user_transition_availabilities'
        expect(response).to have_http_status(:ok)
      end

      context 'When the user has an associated AcceptableVerifiedCredential' do
        let!(:user_acceptable_verified_credential) do
          create(:user_acceptable_verified_credential, :with_avc, user_account:)
        end

        it 'returns false for organic adoption modal' do
          get '/v0/user_transition_availabilities'
          json_body = JSON.parse(response.body)
          expect(json_body).to include 'organic_modal' => false
        end
      end

      context 'When the user has an associated IdmeVerifiedCredential' do
        let!(:user_acceptable_verified_credential) do
          create(:user_acceptable_verified_credential, :with_ivc, user_account:)
        end

        it 'returns false for organic adoption modal' do
          get '/v0/user_transition_availabilities'
          json_body = JSON.parse(response.body)
          expect(json_body).to include 'organic_modal' => false
        end
      end

      context 'When the user does not have associated AVC or IVC' do
        let!(:user_acceptable_verified_credential) do
          create(:user_acceptable_verified_credential, :without_avc_ivc, user_account:)
        end

        it 'returns true for organic adoption modal' do
          get '/v0/user_transition_availabilities'
          json_body = JSON.parse(response.body)
          expect(json_body).to include 'organic_modal' => true
          expect(json_body).to include 'credential_type' => SAML::User::DSLOGON_CSID
        end
      end
    end

    context 'when Flipper organic_conversion_experiment is disabled' do
      before do
        Flipper.disable(:organic_conversion_experiment)
      end

      it 'is a valid request' do
        get '/v0/user_transition_availabilities'
        expect(response).to have_http_status(:ok)
      end

      context 'When the user has an associated AcceptableVerifiedCredential' do
        let!(:user_acceptable_verified_credential) do
          create(:user_acceptable_verified_credential, :with_avc, user_account:)
        end

        it 'returns false for organic adoption modal' do
          get '/v0/user_transition_availabilities'
          json_body = JSON.parse(response.body)
          expect(json_body).to include 'organic_modal' => false
        end
      end

      context 'When the user has an associated IdmeVerifiedCredential' do
        let!(:user_acceptable_verified_credential) do
          create(:user_acceptable_verified_credential, :with_ivc, user_account:)
        end

        it 'returns false for organic adoption modal' do
          get '/v0/user_transition_availabilities'
          json_body = JSON.parse(response.body)
          expect(json_body).to include 'organic_modal' => false
        end
      end

      context 'When the user does not have associated AVC or IVC' do
        let!(:user_acceptable_verified_credential) do
          create(:user_acceptable_verified_credential, :without_avc_ivc, user_account:)
        end

        it 'returns false for organic adoption modal' do
          get '/v0/user_transition_availabilities'
          json_body = JSON.parse(response.body)
          expect(json_body).to include 'organic_modal' => false
        end
      end
    end
  end
end
