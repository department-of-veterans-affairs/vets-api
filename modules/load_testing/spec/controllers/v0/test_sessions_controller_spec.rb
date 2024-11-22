require 'rails_helper'

RSpec.describe LoadTesting::V0::TestSessionsController, type: :controller do
  routes { LoadTesting::Engine.routes }

  describe 'POST #create' do
    let(:valid_params) do
      {
        concurrent_users: 100,
        client_id: 'test_client',
        type: 'logingov',
        acr: 'http://idmanagement.gov/ns/assurance/ial/2'
      }
    end

    it 'creates a new test session' do
      expect { post :create, params: valid_params }
        .to change(LoadTesting::TestSession, :count).by(1)
    end

    it 'generates initial tokens' do
      post :create, params: valid_params
      session = LoadTesting::TestSession.last
      expect(session.test_tokens.count).to eq(session.concurrent_users)
    end
  end

  describe 'GET #show' do
    let!(:test_session) { create(:load_testing_test_session) }

    it 'returns the test session' do
      get :show, params: { id: test_session.id }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['id']).to eq(test_session.id)
    end
  end
end 