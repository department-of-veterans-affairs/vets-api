# frozen_string_literal: true

require 'rails_helper'
require 'support/error_details'

describe 'user_preferences', type: :request do
  include SchemaMatchers
  include ErrorDetails

  let(:user) { build(:user, :accountable) }
  let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
  let(:auth_header) do
    {
      'Authorization' => "Token token=#{token}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end
  let(:preference_1) { create :preference }
  let(:preference_2) { create :preference }
  let(:choice_1) { create :preference_choice, preference: preference_1 }
  let(:choice_2) { create :preference_choice, preference: preference_1 }
  let(:choice_3) { create :preference_choice, preference: preference_2 }
  let(:choice_4) { create :preference_choice, preference: preference_2 }
  let(:request_body) do
    [
      {
        preference: {
          code: preference_1.code
        },
        user_preferences: [
          { code: choice_1.code },
          { code: choice_2.code }
        ]
      },
      {
        preference: {
          code: preference_2.code
        },
        user_preferences: [
          { code: choice_3.code },
          { code: choice_4.code }
        ]
      }
    ]
  end

  before do
    Session.create(uuid: user.uuid, token: token)
    User.create(user)
  end

  describe 'POST /v0/user/preferences' do
    it 'returns the expected shape of attributes', :aggregate_failures do
      post '/v0/user/preferences', request_body.to_json, auth_header

      expect(response).to have_http_status(:ok)
      expect(response).to match_response_schema('user_preferences')
    end

    context 'current user does not have an Account record' do
      let(:user_wo_account) { build(:user, :loa3) }

      before do
        Session.create(uuid: user_wo_account.uuid, token: token)
        User.create(user_wo_account)
      end

      it 'creates an Account record for the current user', :aggregate_failures do
        expect(user_wo_account.account).to be_nil

        post '/v0/user/preferences', request_body.to_json, auth_header

        expect(user_wo_account.account).to be_present
        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('user_preferences')
      end
    end

    context 'when a passed Preference#code is not in the db' do
      let(:non_existant_code) { 'code-that-does-not-exist' }
      let(:bad_request_body) do
        [
          {
            preference: { code: non_existant_code },
            user_preferences: [{ code: choice_1.code }]
          }
        ].to_json
      end

      it 'returns a 404 not found', :aggregate_failures do
        post '/v0/user/preferences', bad_request_body, auth_header

        expect(response).to have_http_status(:not_found)
        expect(error_details_for(response, key: 'title')).to eq 'Record not found'
        expect(
          error_details_for(response, key: 'detail')
        ).to eq "The record identified by #{non_existant_code} could not be found"
      end
    end

    context 'when a passed PreferenceChoice#code is not in the db' do
      let(:non_existant_code) { 'code-that-does-not-exist' }
      let(:bad_request_body) do
        [
          {
            preference: { code: preference_1.code },
            user_preferences: [{ code: non_existant_code }]
          }
        ].to_json
      end

      it 'returns a 404 not found', :aggregate_failures do
        post '/v0/user/preferences', bad_request_body, auth_header

        expect(response).to have_http_status(:not_found)
        expect(error_details_for(response, key: 'title')).to eq 'Record not found'
        expect(
          error_details_for(response, key: 'detail')
        ).to eq "The record identified by #{non_existant_code} could not be found"
      end
    end
  end
end
