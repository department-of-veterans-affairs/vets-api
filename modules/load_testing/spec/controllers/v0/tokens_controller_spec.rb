require 'rails_helper'

RSpec.describe LoadTesting::V0::TokensController, type: :controller do
  routes { LoadTesting::Engine.routes }

  describe 'GET #next' do
    let(:test_session) { create(:load_testing_test_session) }
    let!(:valid_token) do
      create(:load_testing_test_token,
             test_session: test_session,
             expires_at: 25.minutes.from_now)
    end

    it 'returns a valid token' do
      get :next, params: { id: test_session.id }
      expect(response).to have_http_status(:ok)
      
      token = JSON.parse(response.body)
      expect(token['refresh_token']).to be_present
      expect(token['device_secret']).to be_present
    end

    context 'when no valid tokens exist' do
      before { valid_token.update(expires_at: 4.minutes.from_now) }

      it 'generates a new token' do
        expect { get :next, params: { id: test_session.id } }
          .to change { test_session.test_tokens.count }.by(1)
      end
    end
  end
end 