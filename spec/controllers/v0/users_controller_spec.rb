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
        expect(claims['ch33_bank_accounts']).to be(false)
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

    context 'when profile claims enabled' do
      before do
        Flipper.enable(:profile_user_claims)
      end

      it 'returns a JSON user profile with claims' do
        get :show
        json = json_body_for(response)
        expect(response).to be_successful

        claims = json.dig('attributes', 'profile', 'claims')
        expect(claims['ch33_bank_accounts']).to be(true)
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
end
