# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::PreferencesController, type: :controller do
  include RequestHelper

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

      it 'returns a single Preference' do
        get :show, code: preference.code
        preference_code = json_body_for(response)['attributes']['code']
        expect(preference_code).to eq preference.code
      end

      it 'returns all PreferenceChoices for given Preference' do
        preference_choices = json_body_for(response)['attributes']['preference_choices']
        preference_choice_ids = preference_choices.map { |pc| pc['id'] }
        expect(preference_choice_ids).to match_array preference.choices.ids
      end

      it 'raises a 404 if preference cannot be found' do
        get :show, code: 'wrong'
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
