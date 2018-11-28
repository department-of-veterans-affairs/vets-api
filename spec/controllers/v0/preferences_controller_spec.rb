# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::PreferencesController, type: :controller do
  include RequestHelper
  include SchemaMatchers

  describe '#show' do
    let(:preference) { create(:preference, :with_choices) }

    context 'when not logged in' do
      it 'returns unauthorized' do
        get :show, code: preference.code
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when logged in as an LOA1 user' do
      include_context 'login_as_loa1'

      before(:each) do
        login_as_loa1
        get :show, code: preference.code
      end

      it 'returns successful http status' do
        expect(response).to have_http_status(:success)
      end

      it 'matches the response schema' do
        expect(response).to match_response_schema('preferences')
      end

      it 'returns a single Preference' do
        get :show, code: preference.code
        preference_code = json_body_for(response)['attributes']['code']
        expect(preference_code).to eq preference.code
      end

      it 'returns all PreferenceChoices for given Preference' do
        preference_choices = json_body_for(response)['attributes']['preference_choices']
        preference_choice_codes = preference_choices.map { |pc| pc['code'] }

        expect(preference_choice_codes).to match_array preference.choices.map(&:code)
      end

      it 'raises a 404 if preference cannot be found' do
        get :show, code: 'wrong'
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe '#index' do
    let!(:first_preference) { create(:preference, :with_choices) }
    let!(:second_preference) { create(:preference, :with_choices) }

    context 'when not logged in' do
      it 'returns unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when logged in as an LOA1 user' do
      include_context 'login_as_loa1'

      before(:each) do
        login_as_loa1
        get :index
      end

      it 'returns successful http status' do
        expect(response).to have_http_status(:success)
      end

      it 'matches the response schema' do
        expect(response).to match_response_schema('preferences')
      end

      it 'returns all existing Preferences with their choices' do
        body = json_body_for(response)
        first_preference_code = body[0]['attributes']['code']

        expect(body.size).to eq 2
        expect(first_preference_code).to eq first_preference.code
      end

      it 'returns all PreferenceChoices for given Preference' do
        preference_choices = json_body_for(response)[0]['attributes']['preference_choices']
        preference_choice_codes = preference_choices.map { |pc| pc['code'] }

        expect(preference_choice_codes).to match_array first_preference.choices.map(&:code)
      end
    end
  end
end
