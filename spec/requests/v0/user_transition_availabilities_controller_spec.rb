# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::UserTransitionAvailabilitiesController, type: :request do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  describe '/v0/user_transition_availabilities' do
    context 'when Flipper organic_dsl_conversion_experiment is enabled' do
      it 'is a valid request' do
        get '/v0/user_transition_availabilities'
        expect(response).to have_http_status(:ok)
      end

      context 'When the user has an associated AcceptableVerifiedCredential' do
        let(:user) { create(:user, :accountable_with_logingov_uuid) }

        it 'returns false for organic adoption modal' do
          get '/v0/user_transition_availabilities'
          json_body = JSON.parse(response.body)
          expect(json_body).to include 'organic_modal' => false
        end
      end

      context 'When the user has an associated IdmeVerifiedCredential' do
        let(:user) { create(:user, :accountable) }

        it 'returns false for organic adoption modal' do
          get '/v0/user_transition_availabilities'
          json_body = JSON.parse(response.body)
          expect(json_body).to include 'organic_modal' => false
        end
      end

      context 'When the user does not have associated AVC or IVC' do
        let(:user) { create(:user, :dslogon) }

        it 'returns true for organic adoption modal' do
          get '/v0/user_transition_availabilities'
          json_body = JSON.parse(response.body)
          expect(json_body).to include 'organic_modal' => true
        end
      end
    end

    context 'when Flipper organic_dsl_conversion_experiment is disabled' do
      before do
        Flipper.disable(:organic_dsl_conversion_experiment)
      end

      it 'is a valid request' do
        get '/v0/user_transition_availabilities'
        expect(response).to have_http_status(:ok)
      end

      context 'When the user has an associated AcceptableVerifiedCredential' do
        let(:user) { create(:user, :accountable_with_logingov_uuid) }

        it 'returns false for organic adoption modal' do
          get '/v0/user_transition_availabilities'
          json_body = JSON.parse(response.body)
          expect(json_body).to include 'organic_modal' => false
        end
      end

      context 'When the user has an associated IdmeVerifiedCredential' do
        let(:user) { create(:user, :accountable) }

        it 'returns false for organic adoption modal' do
          get '/v0/user_transition_availabilities'
          json_body = JSON.parse(response.body)
          expect(json_body).to include 'organic_modal' => false
        end
      end

      context 'When the user does not have associated AVC or IVC' do
        let(:user) { create(:user, :dslogon) }

        it 'returns false for organic adoption modal' do
          get '/v0/user_transition_availabilities'
          json_body = JSON.parse(response.body)
          expect(json_body).to include 'organic_modal' => false
        end
      end
    end
  end
end
