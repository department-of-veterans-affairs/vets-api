# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::UserPermissionsController, type: :controller do
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
    end

    context 'when profile claims enabled' do
      before do
        Flipper.enable(:profile_user_claims)
      end

      it 'returns a JSON user profile with claims' do
        get :show
        expect(response).to be_successful

        json = JSON.parse(response.body)
        expect(json['cnp_direct_deposit']).to be(false)
        expect(json['communication_preferences']).to be(false)
        expect(json['connected_apps']).to be(true)
        expect(json['edu_direct_deposit']).to be(false)
        expect(json['military_history']).to be(false)
        expect(json['payment_history']).to be(false)
        expect(json['personal_information']).to be(true)
        expect(json['rating_info']).to be(false)
      end
    end
  end

  context 'when logged in as an LOA3 user' do
    before do
      sign_in_as(user)
    end

    context 'when profile claims enabled' do
      let(:user) { build(:user, :loa3) }

      before do
        Flipper.enable(:profile_user_claims)
      end

      it 'returns a JSON user profile with claims' do
        get :show
        expect(response).to be_successful

        json = JSON.parse(response.body)
        expect(json['cnp_direct_deposit']).to be(true)
        expect(json['communication_preferences']).to be(true)
        expect(json['connected_apps']).to be(true)
        expect(json['edu_direct_deposit']).to be(true)
        expect(json['military_history']).to be(true)
        expect(json['payment_history']).to be(true)
        expect(json['personal_information']).to be(true)
        expect(json['rating_info']).to be(true)
      end
    end

    context 'when user is missing ICN' do
      let(:user) { build(:user, :loa3, icn: nil) }

      before do
        Flipper.enable(:profile_user_claims)
      end

      it 'returns a JSON user profile with claims' do
        get :show
        expect(response).to be_successful

        json = JSON.parse(response.body)
        expect(json['cnp_direct_deposit']).to be(false)
        expect(json['communication_preferences']).to be(true)
        expect(json['connected_apps']).to be(true)
        expect(json['edu_direct_deposit']).to be(true)
        expect(json['military_history']).to be(true)
        expect(json['payment_history']).to be(false)
        expect(json['personal_information']).to be(true)
        expect(json['rating_info']).to be(false)
      end
    end
  end
end
