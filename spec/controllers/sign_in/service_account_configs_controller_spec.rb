# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::ServiceAccountConfigsController, type: :controller do
  let(:service_account_config) { create(:service_account_config, scopes:) }
  let(:service_account_id) { service_account_config.service_account_id }
  let(:scopes) { ['http://www.example.com/sign_in/service_account_configs'] }
  let(:service_account_access_token) { create(:service_account_access_token, service_account_id:, scopes:) }
  let(:sts_token) { SignIn::ServiceAccountAccessTokenJwtEncoder.new(service_account_access_token:).perform }
  let(:valid_attributes) { attributes_for(:service_account_config) }
  let(:invalid_attributes) { attributes_for(:service_account_config, service_account_id: nil) }
  let(:response_body) { JSON.parse(response.body) }

  before do
    controller.request.headers['Authorization'] = "Bearer #{sts_token}"
  end

  describe 'GET #index' do
    context 'when authenticated' do
      it 'returns a success response' do
        get :index, params: { service_account_ids: [service_account_id] }
        expect(response).to be_successful
        expect(response_body.pluck('service_account_id')).to include(service_account_id)
      end
    end

    context 'when not authenticated' do
      let(:sts_token) { 'invalid_token' }

      it 'returns an unauthorized response' do
        get :index, params: { service_account_ids: [service_account_id] }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    context 'when authenticated' do
      context 'when the client config exists' do
        it 'returns a success response' do
          get :show, params: { service_account_id: }
          expect(response).to be_successful
          expect(response_body['service_account_id']).to eq(service_account_id)
        end
      end

      context 'when the client config does not exist' do
        let(:service_account_id) { 'non_existent_service_account_id' }

        it 'returns a not found response' do
          get :show, params: { service_account_id: }
          expect(response).to have_http_status(:not_found)
          expect(response_body.dig('errors', 'service_account_config')).to include('not found')
        end
      end
    end

    context 'when not authenticated' do
      let(:sts_token) { 'invalid_token' }

      it 'returns an unauthorized response' do
        get :show, params: { service_account_id: }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #create' do
    context 'when authenticated' do
      context 'with valid params' do
        it 'creates a new SignIn::ServiceAccountConfig' do
          expect do
            post :create, params: { service_account_config: valid_attributes }, as: :json
          end.to change(SignIn::ServiceAccountConfig, :count).by(1)
        end

        it 'returns a created response' do
          post :create, params: { service_account_config: valid_attributes }, as: :json
          expect(response).to have_http_status(:created)
          expect(response_body['service_account_id']).to eq(valid_attributes[:service_account_id])
        end
      end

      context 'with invalid params' do
        it 'does not create a new SignIn::ServiceAccountConfig' do
          expect do
            post :create, params: { service_account_config: invalid_attributes }, as: :json
          end.not_to change(SignIn::ServiceAccountConfig, :count)
        end

        it 'renders an error' do
          post :create, params: { service_account_config: invalid_attributes }, as: :json
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response_body.dig('errors', 'service_account_id')).to include("can't be blank")
        end
      end
    end

    context 'when not authenticated' do
      let(:sts_token) { 'invalid_token' }

      it 'returns an unauthorized response' do
        post :create, params: { service_account_config: valid_attributes }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT #update' do
    context 'when authenticated' do
      context 'with valid params' do
        let(:new_attributes) { attributes_for(:service_account_config, service_account_id:) }

        it 'updates the requested service_account_config' do
          put :update, params: { service_account_id:, service_account_config: new_attributes },
                       as: :json
          service_account_config.reload
          expect(service_account_config.service_account_id).to eq(service_account_id)
        end
      end

      context 'with invalid params' do
        it 'renders an error' do
          put :update, params: { service_account_id:, service_account_config: invalid_attributes },
                       as: :json
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response_body.dig('errors', 'service_account_id')).to include("can't be blank")
        end
      end
    end

    context 'when not authenticated' do
      let(:sts_token) { 'invalid_token' }

      it 'returns an unauthorized response' do
        put :update, params: { service_account_id:, service_account_config: valid_attributes },
                     as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when authenticated' do
      context 'when the service_account_config exists' do
        it 'destroys the requested service_account_config' do
          expect do
            delete :destroy, params: { service_account_id: }
          end.to change(SignIn::ServiceAccountConfig, :count).by(-1)
        end

        it 'returns a no content response' do
          delete :destroy, params: { service_account_id: }
          expect(response).to have_http_status(:no_content)
        end
      end

      context 'when the service_account_config does not exist' do
        let(:service_account_id) { 'non_existent_service_account_id' }

        it 'returns a not found response' do
          delete :destroy, params: { service_account_id: }
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when not authenticated' do
      let(:sts_token) { 'invalid_token' }

      it 'returns an unauthorized response' do
        delete :destroy, params: { service_account_id: }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'permitted params' do
    let(:service_account_config) { build(:service_account_config) }
    let(:attributes) { service_account_config.attributes.symbolize_keys }

    let(:expected_permitted_params) do
      array_params, params = attributes.excluding(:id, :created_at, :updated_at)
                                       .partition { |_, v| v.is_a?(Array) }
      params.to_h.keys << array_params.to_h.transform_values { [] }
    end

    it 'permits the expected params' do
      expect(subject).to permit(*expected_permitted_params)
        .for(:create, params: { service_account_config: attributes })
    end
  end
end
