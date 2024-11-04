# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::UsersController, type: :controller do
  include RequestHelper

  context 'when not logged in' do
    it 'returns unauthorized' do
      get :show
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when logged in as an LOA1 user' do
    let(:user) { build(:user, :loa1) }

    before do
      sign_in_as(user)
      create(:user_verification, idme_uuid: user.idme_uuid)
      create(:in_progress_form, user_uuid: user.uuid, form_id: 'edu-1990')
    end

    it 'returns a JSON user profile' do
      get :show
      json = json_body_for(response)
      expect(response).to be_successful
      expect(json['attributes']['profile']['email']).to eq(user.email)
    end

    context 'when profile claims enabled' do
      before do
        Flipper.enable(:profile_user_claims)
      end

      it 'returns a JSON user profile with claims' do
        get :show
        json = json_body_for(response)
        expect(response).to be_successful

        claims = json.dig('attributes', 'profile', 'claims')
        expect(claims['communication_preferences']).to be(false)
        expect(claims['connected_apps']).to be(true)
        expect(claims['military_history']).to be(false)
        expect(claims['payment_history']).to be(false)
        expect(claims['personal_information']).to be(true)
        expect(claims['rating_info']).to be(false)
        expect(claims['appeals']).to be(false)
        expect(claims['medical_copays']).to be(false)
      end
    end
  end

  context 'when logged in as a vet360 user' do
    let(:user) { build(:user, :loa3) }

    before do
      sign_in_as(user)
      Flipper.disable(:profile_user_claims)
      create(:user_verification, idme_uuid: user.idme_uuid)
    end

    it 'returns a JSON user profile with a bad_address' do
      get :show
      json = json_body_for(response)

      mailing_address = json.dig('attributes', 'vet360_contact_information', 'mailing_address')

      expect(response).to be_successful
      expect(mailing_address.key?('bad_address')).to be(true)
    end

    it 'returns a JSON user profile without claims' do
      get :show
      json = json_body_for(response)
      expect(response).to be_successful

      claims = json.dig('attributes', 'profile', 'claims')
      expect(claims).to be(nil)
    end

    context 'onboarding' do
      it 'returns a JSON user with onboarding information when the feature toggle is enabled' do
        Flipper.enable(:veteran_onboarding_beta_flow, user)
        get :show
        json = json_body_for(response)
        expect(response).to be_successful
        onboarding = json.dig('attributes', 'onboarding')
        expect(onboarding['show']).to be(true)
      end

      it 'returns a JSON user without onboarding information when the feature toggle is disabled' do
        Flipper.disable(:veteran_onboarding_beta_flow)
        Flipper.disable(:veteran_onboarding_show_to_newly_onboarded)
        get :show
        json = json_body_for(response)
        expect(response).to be_successful
        onboarding = json.dig('attributes', 'onboarding')
        expect(onboarding['show']).to be(nil)
      end
    end

    context 'when profile claims enabled' do
      before do
        Flipper.enable(:profile_user_claims)
      end

      it 'returns a JSON user profile with claims' do
        get :show
        json = json_body_for(response)
        expect(response).to be_successful

        claims = json.dig('attributes', 'profile', 'claims')
        expect(claims['communication_preferences']).to be(true)
        expect(claims['connected_apps']).to be(true)
        expect(claims['military_history']).to be(true)
        expect(claims['payment_history']).to be(true)
        expect(claims['personal_information']).to be(true)
        expect(claims['rating_info']).to be(true)
        expect(claims['appeals']).to be(true)
        expect(claims['medical_copays']).to be(true)
      end
    end
  end

  describe '#icn' do
    let(:user) { build(:user, :loa1) }

    context 'when logged in' do
      let(:expected_response) { { icn: user.icn }.as_json }

      before do
        sign_in_as(user)
      end

      it 'returns the users icn' do
        get :icn

        expect(response).to be_successful
        expect(JSON.parse(response.body)).to eq(expected_response)
      end
    end

    context 'when not logged in' do
      it 'returns unauthorized' do
        get :icn

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe '#credential_emails' do
    let(:user) { build(:user, :loa3) }
    let(:user_account) { create(:user_account) }
    let(:user_credential_email1) { create(:user_credential_email, credential_email: 'email1@example.com') }
    let(:user_credential_email2) { create(:user_credential_email, credential_email: 'email2@example.com') }
    let!(:idme_user_verification) do
      create(:user_verification, idme_uuid: user.idme_uuid, user_credential_email: user_credential_email1,
                                 user_account_id: user_account.id)
    end
    let!(:logingov_user_verification) do
      create(:user_verification, logingov_uuid: user.logingov_uuid, user_credential_email: user_credential_email2,
                                 user_account_id: user_account.id)
    end
    let(:expected_response) do
      { idme_user_verification.credential_type => user_credential_email1.credential_email,
        logingov_user_verification.credential_type => user_credential_email2.credential_email }
    end

    before do
      sign_in user
    end

    it 'returns the users credential emails' do
      get :credential_emails
      expect(response).to be_successful
      expect(JSON.parse(response.body)).to eq(expected_response)
    end
  end
end
