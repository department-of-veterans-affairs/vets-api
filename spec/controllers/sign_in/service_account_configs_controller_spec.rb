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

      context 'with certs_attributes' do
        context 'when a cert with the pem already exists' do
          let!(:cert) { create(:sign_in_certificate) }

          it 'associates the existing cert with the service account config' do
            post :create,
                 params: {
                   service_account_config: valid_attributes.merge(certs_attributes: [cert.attributes])
                 }, as: :json
            expect(response).to have_http_status(:created)
            expect(response_body['certs']).to include(a_hash_including('id' => cert.id))
            expect(SignIn::ServiceAccountConfig.last.certs).to include(cert)
          end

          it 'does not create a new certificate' do
            expect do
              post :create,
                   params: {
                     service_account_config: valid_attributes.merge(certs_attributes: [cert.attributes])
                   }, as: :json
            end.not_to change(SignIn::Certificate, :count)
          end
        end

        context 'when a cert with the pem does not exist' do
          let(:cert) { build(:sign_in_certificate) }

          it 'creates a new certificate for the service account config' do
            post :create,
                 params: {
                   service_account_config: valid_attributes.merge(certs_attributes: [cert.attributes])
                 }, as: :json
            expect(response).to have_http_status(:created)
            expect(response_body['certs']).to include(a_hash_including('pem' => cert.pem))
            expect(SignIn::Certificate.count).to eq(1)
          end
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

      context 'with certs_attributes' do
        let(:cert) { create(:sign_in_certificate) }

        it 'updates the service account config with new certificates' do
          put :update,
              params: { service_account_id:,
                        service_account_config: valid_attributes.merge(certs_attributes: [cert.attributes]) },
              as: :json
          expect(response).to have_http_status(:ok)
          expect(response_body['certs']).to include(a_hash_including('id' => cert.id))
        end

        context 'when certs_attributes are empty' do
          it 'does not update the certs' do
            put :update, params: { service_account_id:,
                                   service_account_config: valid_attributes.merge(certs_attributes: []) }, as: :json
            expect(response).to have_http_status(:ok)
            expect(response_body['certs']).to be_empty
          end
        end

        context 'when certs_attributes contains _destroy' do
          let(:cert_to_destroy) { create(:sign_in_certificate) }

          before do
            service_account_config.certs << cert_to_destroy
          end

          it 'destroys the specified certificate' do
            put :update, params: {
              service_account_id:,
              service_account_config: {
                certs_attributes: [{ id: cert_to_destroy.id, _destroy: '1' }]
              },
              as: :json
            }
            expect(response).to have_http_status(:ok)
          end
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
end
