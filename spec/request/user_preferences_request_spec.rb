# frozen_string_literal: true

require 'rails_helper'
require 'support/error_details'

describe 'user_preferences', type: :request do
  include SchemaMatchers
  include ErrorDetails

  let(:user) { build(:user, :accountable) }
  let(:headers) do
    {
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

  before { sign_in_as(user) }

  describe 'POST /v0/user/preferences' do
    it 'returns the expected shape of attributes', :aggregate_failures do
      post '/v0/user/preferences', params: request_body.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response).to match_response_schema('user_preferences')
    end

    context 'current user does not have an Account record' do
      let(:user) { build(:user, :loa3) }

      before do
        account = Account.find_by(idme_uuid: user.uuid)

        expect(account).to be_nil
      end

      it 'creates an Account record for the current user', :aggregate_failures do
        post '/v0/user/preferences', params: request_body.to_json, headers: headers

        expect(user.account).to be_present
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
        post '/v0/user/preferences', params: bad_request_body, headers: headers

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
        post '/v0/user/preferences', params: bad_request_body, headers: headers

        expect(response).to have_http_status(:not_found)
        expect(error_details_for(response, key: 'title')).to eq 'Record not found'
        expect(
          error_details_for(response, key: 'detail')
        ).to eq "The record identified by #{non_existant_code} could not be found"
      end
    end

    context 'when an empty UserPreference array is supplied in the request body' do
      let(:empty_user_preference_request) do
        [
          {
            preference: {
              code: preference_1.code
            },
            user_preferences: []
          }
        ]
      end

      it 'returns a 400 bad request with details', :aggregate_failures do
        post '/v0/user/preferences', params: empty_user_preference_request.to_json, headers: headers

        body  = JSON.parse response.body
        error = body['errors'].first

        expect(response).to have_http_status(:bad_request)
        expect(error['status']).to eq '400'
        expect(error['title']).to eq 'Missing parameter'
        expect(error['detail']).to include 'user_preferences'
      end
    end

    context 'when a :preference is not supplied in the request body' do
      let(:empty_preference_request) do
        [
          {
            user_preferences: [{ code: choice_1.code }]
          }
        ]
      end

      it 'returns a 400 bad request with details', :aggregate_failures do
        post '/v0/user/preferences', params: empty_preference_request.to_json, headers: headers

        body  = JSON.parse response.body
        error = body['errors'].first

        expect(response).to have_http_status(:bad_request)
        expect(error['status']).to eq '400'
        expect(error['title']).to eq 'Missing parameter'
        expect(error['detail']).to include 'preference#code'
      end
    end

    context 'with problems trying to destroy the existing UserPreference records' do
      it 'returns a 422 with details', :aggregate_failures do
        allow(UserPreference).to receive(:for_preference_and_account).and_raise(
          ActiveRecord::RecordNotDestroyed.new('Cannot destroy this record')
        )

        post '/v0/user/preferences', params: request_body.to_json, headers: headers

        body  = JSON.parse response.body
        error = body['errors'].first

        expect(response).to have_http_status(:unprocessable_entity)
        expect(error['status']).to eq '422'
        expect(error['title']).to eq 'Unprocessable Entity'
        expect(error['detail']).to include 'ActiveRecord::RecordNotDestroyed'
      end
    end
  end

  describe 'DELETE /v0/user/preferences/:code' do
    before do
      notifications = create(:preference, :notifications)
      UserPreference.create(account_id: user.account.id,
                            preference_id: notifications.id,
                            preference_choice_id: notifications.choices.first.id)

      UserPreference.create(account_id: user.account.id,
                            preference_id: notifications.id,
                            preference_choice_id: notifications.choices.last.id)
    end

    context 'when a user has UserPreferences' do
      it 'deletes all of a User\'s UserPreferences', :aggregate_failures do
        delete '/v0/user/preferences/notifications/delete_all', headers: headers

        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('delete_all_user_preferences')
        expect(UserPreference.where(account_id: user.account.id).count).to eq 0
      end
    end

    context 'when given a non existant code' do
      it 'returns a 404 not found', :aggregate_failures do
        delete '/v0/user/preferences/garbagecode/delete_all', headers: headers

        expect(response).to have_http_status(:not_found)
        expect(error_details_for(response, key: 'title')).to eq 'Record not found'
        expect(error_details_for(response, key: 'status')).to eq '404'
      end
    end

    context 'when records cannot be destroyed' do
      it 'returns a 422 unprocessable', :aggregate_failures do
        allow(UserPreference).to receive(:for_preference_and_account).and_raise(
          ActiveRecord::RecordNotDestroyed.new('Cannot destroy this record')
        )

        delete '/v0/user/preferences/notifications/delete_all', headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to match_response_schema('errors')
        expect(error_details_for(response, key: 'title')).to eq 'Unprocessable Entity'
        expect(error_details_for(response, key: 'status')).to eq '422'
        expect(error_details_for(response, key: 'detail')).to include 'ActiveRecord::RecordNotDestroyed'
      end
    end
  end

  describe 'GET /v0/user/preferences' do
    before do
      benefits = create(:preference, :benefits)
      notifications = create(:preference, :notifications)
      UserPreference.create(account_id: user.account.id,
                            preference_id: benefits.id,
                            preference_choice_id: benefits.choices.first.id)

      UserPreference.create(account_id: user.account.id,
                            preference_id: notifications.id,
                            preference_choice_id: notifications.choices.first.id)

      UserPreference.create(account_id: user.account.id,
                            preference_id: notifications.id,
                            preference_choice_id: notifications.choices.last.id)
    end

    it 'returns an index of all of the user\'s preferences' do
      get '/v0/user/preferences', headers: headers

      expect(response).to be_ok
      expect(response).to match_response_schema('user_preferences')
    end
  end
end
