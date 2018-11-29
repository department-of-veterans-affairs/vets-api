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
    context 'when the User does *not* already have UserPreference records for the Preference' do
      it 'returns the expected shape of attributes', :aggregate_failures do
        post '/v0/user/preferences', request_body.to_json, auth_header

        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('user_preferences')
      end

      it 'creates UserPreference records' do
        expect {
          post '/v0/user/preferences', request_body.to_json, auth_header
        }.to change{ UserPreference.count }.from(0).to(4)
      end

      it 'creates UserPreference records for the passed user Account' do
        post '/v0/user/preferences', request_body.to_json, auth_header

        expect(UserPreference.pluck(:account_id).uniq).to eq [user.account.id]
      end

      it 'creates UserPreference records for the passed Preferences', :aggregate_failures do
        post '/v0/user/preferences', request_body.to_json, auth_header

        expect(UserPreference.where(preference_id: preference_1.id).count).to eq 2
        expect(UserPreference.where(preference_id: preference_2.id).count).to eq 2
      end

      it 'returns the Preference and PreferenceChoices that were associated in the new UserPreferences', :aggregate_failures do
        post '/v0/user/preferences', request_body.to_json, auth_header

        returned_codes_1 = returned_user_preference_codes_in(response, preference_1)
        returned_codes_2 = returned_user_preference_codes_in(response, preference_2)

        expect(returned_codes_1).to match_array [choice_1.code, choice_2.code]
        expect(returned_codes_2).to match_array [choice_3.code, choice_4.code]
      end
    end

    context 'when the User already has UserPreference records for the Preference' do
      let!(:user_preference_1) { create_user_preference(preference_1, choice_1) }
      let!(:user_preference_2) { create_user_preference(preference_1, choice_2) }
      let!(:user_preference_3) { create_user_preference(preference_2, choice_3) }
      let!(:user_preference_4) { create_user_preference(preference_2, choice_4) }
      let!(:existing_user_preference_ids) { UserPreference.pluck(:id) }
      let(:choice_5) { create :preference_choice, preference: preference_1 }
      let(:choice_6) { create :preference_choice, preference: preference_1 }
      let(:choice_7) { create :preference_choice, preference: preference_2 }
      let(:choice_8) { create :preference_choice, preference: preference_2 }
      let(:request_body) do
        [
          {
            preference: {
              code: preference_1.code
            },
            user_preferences: [
              { code: choice_5.code },
              { code: choice_6.code }
            ]
          },
          {
            preference: {
              code: preference_2.code
            },
            user_preferences: [
              { code: choice_7.code },
              { code: choice_8.code }
            ]
          }
        ]
      end

      before { expect(UserPreference.count).to eq 4 }

      it "deletes the user's existing records for the associated Preference and creates new ones", :aggregate_failures do
        post '/v0/user/preferences', request_body.to_json, auth_header

        existing_user_preference_ids.each do |user_preference_id|
          expect(UserPreference.find_by(id: user_preference_id)).to be_nil
        end
      end

      it 'creates new UserPreference records', :aggregate_failures do
        post '/v0/user/preferences', request_body.to_json, auth_header

        expect(UserPreference.count).to eq 4
        expect(existing_user_preference_ids).to_not match_array UserPreference.pluck(:id)
      end

      it 'returns the Preference and PreferenceChoices that were associated in the new UserPreferences', :aggregate_failures do
        post '/v0/user/preferences', request_body.to_json, auth_header

        returned_codes_1 = returned_user_preference_codes_in(response, preference_1)
        returned_codes_2 = returned_user_preference_codes_in(response, preference_2)

        expect(returned_codes_1).to match_array [choice_5.code, choice_6.code]
        expect(returned_codes_2).to match_array [choice_7.code, choice_8.code]
      end

      context 'when the user has other non-related UserPreferences in place' do
        let(:some_preference) { create(:preference) }
        let(:some_choice) { create(:preference_choice) }
        let!(:other_user_preference) { create_user_preference(some_preference, some_choice) }

        before do
          expect(user.account.user_preferences.count).to eq 5
          expect(user.account.user_preferences).to include other_user_preference
        end

        it 'does not delete UserPreference records that are not associated with the passed Preferences' do
          post '/v0/user/preferences', request_body.to_json, auth_header

          expect(user.account.user_preferences).to include other_user_preference
        end
      end
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

def create_user_preference(preference, preference_choice)
  create(
    :user_preference,
    account: user.account,
    preference: preference,
    preference_choice: preference_choice
  )
end

def returned_user_preference_codes_in(response, preference)
    body     = JSON.parse response.body
    pairings = body.dig('data', 'attributes', 'user_preferences')
    pairings = pairings.select { |pair| pair['code'] == preference.code }

    pairings.first.dig('user_preferences').map { |pref| pref['code'] }
end
