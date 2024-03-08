# frozen_string_literal: true

require 'rails_helper'
# This spec is currently a request-styled copy of spec/controllers/v0/users_controller_spec.rb and
# will be modified to support representative-specific functionality.
#
# **Important:**  Reference the ZenHub issue for detailed context and changes:
#  https://app.zenhub.com/workspaces/accredited-representative-facing-team-65453a97a9cc36069a2ad1d6/issues/gh/department-of-veterans-affairs/va.gov-team/75746
RSpec.describe 'AccreditedRepresentatives::V0::Users', type: :request do
  include RequestHelper

  before do
    Flipper.enable(:representatives_portal_api)
  end

  describe 'GET /show' do
    context 'when not logged in' do
      it 'returns unauthorized' do
        get '/accredited_representatives/v0/users/show'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when logged in as an LOA1 user' do
      let(:user) { create(:user, :loa1) }

      before do
        sign_in_as(user)
        create(:in_progress_form, user_uuid: user.uuid, form_id: 'edu-1990')
      end

      it 'returns a JSON user profile' do
        get '/accredited_representatives/v0/users/show'
        expect(response).to be_successful
        json = JSON.parse(response.body)
        expect(json['data']['attributes']['profile']['email']).to eq(user.email)
      end

      context 'when profile claims enabled' do
        before do
          Flipper.enable(:profile_user_claims)
        end

        it 'returns a JSON user profile with claims' do
          get '/accredited_representatives/v0/users/show'
          expect(response).to be_successful
          json = JSON.parse(response.body)
          claims = json.dig('data', 'attributes', 'profile', 'claims')
          expect(claims['ch33_bank_accounts']).to be(false)
        end
      end
    end
  end

  describe 'GET /icn' do
    let(:user) { create(:user, :loa1) }

    context 'when not logged in' do
      it 'returns unauthorized' do
        get '/accredited_representatives/v0/users/icn'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when logged in' do
      let(:expected_response) { { icn: user.icn }.as_json }

      before { sign_in_as(user) }

      it 'returns the user\'s icn' do
        get '/accredited_representatives/v0/users/icn'
        expect(response).to be_successful
        expect(JSON.parse(response.body)).to eq({ 'icn' => user.icn }.as_json)
      end
    end
  end
end
