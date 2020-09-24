# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::PreferencesController, type: :controller do
  include RequestHelper
  include SchemaMatchers

  describe '#show' do
    let(:preference) { create(:preference, :with_choices) }

    context 'when not logged in' do
      it 'returns unauthorized' do
        get :show, params: { code: preference.code }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when logged in as an LOA1 user' do
      before do
        sign_in_as(build(:user, :loa1))
        get :show, params: { code: preference.code }
      end

      it 'returns successful http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'matches the response schema' do
        expect(response).to match_response_schema('preference')
      end

      it 'returns a single Preference' do
        get :show, params: { code: preference.code }
        preference_code = json_body_for(response)['attributes']['code']
        expect(preference_code).to eq preference.code
      end

      it 'returns all PreferenceChoices for given Preference' do
        preference_choices = json_body_for(response)['attributes']['preference_choices']
        preference_choice_codes = preference_choices.map { |pc| pc['code'] }

        expect(preference_choice_codes).to match_array preference.choices.map(&:code)
      end

      it 'raises a 404 if preference cannot be found' do
        get :show, params: { code: 'wrong' }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe '#index' do
    let!(:notifications) { create(:preference, :notifications) }
    let!(:benefits) { create(:preference, :benefits) }

    context 'when not logged in' do
      it 'returns unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when logged in as an LOA1 user' do
      before do
        sign_in_as(build(:user, :loa1))
        get :index
      end

      it 'returns successful http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'matches the response schema' do
        expect(response).to match_response_schema('preferences')
      end

      it 'returns all existing Preferences with their choices' do
        preferences = json_body_for(response).dig('attributes', 'preferences')
        expect(preferences.size).to eq Preference.count
      end

      it 'returns all PreferenceChoices for given Preference' do
        body = json_body_for(response)['attributes']['preferences']
        preference_set = body.select { |o| o.dig('code') == 'notifications' }.first
        preference_choice_codes = preference_set['preference_choices'].map { |pc| pc['code'] }

        expect(preference_choice_codes).to match_array notifications.choices.map(&:code)
      end
    end
  end
end
