# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::ClientConfigsController, type: :controller do
  let(:valid_attributes) { attributes_for(:client_config) }
  let(:invalid_attributes) { { client_id: nil } }
  let(:client_config) { create(:client_config) }
  let(:client_id) { client_config.client_id }
  let(:response_body) { JSON.parse(response.body) }

  before do
    allow_any_instance_of(SignIn::ClientConfigsController).to receive(:authenticate_service_account).and_return(true)
  end

  describe 'GET #index' do
    it 'returns a success response' do
      client_config
      get :index, params: {}
      expect(response).to be_successful
    end

    context 'when there is client_ids param' do
      let(:client_config2) { create(:client_config) }

      it 'filters by client_ids if provided' do
        get :index, params: { client_ids: [client_config.client_id, client_config2.client_id] }

        expect(response_body.length).to eq(2)
        expect(response_body.pluck('client_id')).to include(client_config.client_id, client_config2.client_id)
      end
    end
  end

  describe 'GET #show' do
    context 'when the client config does not exist' do
      let(:client_id) { 'non_existent_client_id' }

      it 'returns a not found response' do
        get :show, params: { client_id: }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the client config exists' do
      it 'returns a success response' do
        get :show, params: { client_id: }

        expect(response_body['client_id']).to eq(client_config.client_id)
      end
    end
  end

  describe 'POST #create' do
    context 'with valid params' do
      it 'creates a new SignIn::ClientConfig' do
        post :create, params: { client_config: valid_attributes }, as: :json

        expect(response).to have_http_status(:created)
        expect(response_body['client_id']).to eq(valid_attributes[:client_id])
      end
    end

    context 'with invalid params' do
      it 'does not create a new SignIn::ClientConfig and returns an error' do
        expect do
          post :create, params: { client_config: invalid_attributes }, as: :json
        end.not_to change(SignIn::ClientConfig, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response_body.dig('errors', 'client_id')).to include("can't be blank")
      end
    end
  end

  describe 'PUT #update' do
    context 'with valid params' do
      let(:new_attributes) { { client_id: 'new_client_id' } }

      it 'updates the requested SignIn::ClientConfig' do
        put :update, params: { client_id:, client_config: new_attributes }, as: :json
        client_config.reload
        expect(client_config.client_id).to eq('new_client_id')
      end
    end

    context 'with invalid params' do
      it 'does not update the SignIn::ClientConfig and returns an error' do
        put :update, params: { client_id:, client_config: invalid_attributes }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response_body.dig('errors', 'client_id')).to include("can't be blank")
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when the client config does not exist' do
      let(:client_id) { 'non_existent_client_id' }

      it 'returns a not found response' do
        delete :destroy, params: { client_id: }
        expect(response).to have_http_status(:not_found)
        expect(response_body.dig('errors', 'client_config')).to include('not found')
      end
    end

    context 'when the client config exists' do
      it 'destroys the requested SignIn::ClientConfig' do
        client_config
        expect do
          delete :destroy, params: { client_id:  }
        end.to change(SignIn::ClientConfig, :count).by(-1)
      end
    end
  end
end
