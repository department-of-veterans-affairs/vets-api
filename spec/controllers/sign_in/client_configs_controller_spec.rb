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

    context 'with certs_attributes' do
      context 'when a cert with the pem already exists' do
        let!(:cert) { create(:sign_in_certificate) }

        it 'associates the existing cert with the client config' do
          post :create, params: { client_config: valid_attributes.merge(certs_attributes: [cert.attributes]) },
                        as: :json

          expect(response).to have_http_status(:created)
          expect(response_body['certs']).to include(a_hash_including('id' => cert.id))
          expect(SignIn::ClientConfig.last.certs).to include(cert)
        end

        it 'does not create a new cert' do
          expect do
            post :create, params: { client_config: valid_attributes.merge(certs_attributes: [cert.attributes]) },
                          as: :json
          end.not_to change(SignIn::Certificate, :count)
        end
      end

      context 'when a cert with the pem does not exist' do
        let(:cert) { build(:sign_in_certificate) }

        it 'creates a new certificate and associates it with the client config' do
          post :create, params: { client_config: valid_attributes.merge(certs_attributes: [cert.attributes]) },
                        as: :json

          expect(response).to have_http_status(:created)
          expect(response_body['certs']).to include(a_hash_including('pem' => cert.pem))
          expect(SignIn::Certificate.count).to eq(1)
        end
      end

      context 'when a cert has a validation error' do
        let(:cert) { build(:sign_in_certificate, pem: 'bad_pem') }

        it 'does not create the cert and returns an error' do
          post :create, params: { client_config: valid_attributes.merge(certs_attributes: [cert.attributes]) },
                        as: :json
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response_body.dig('errors',
                                   'config_certificates[0].cert.pem')).to include('not a valid X.509 certificate')
        end
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

    context 'with certs_attributes' do
      let(:cert) { create(:sign_in_certificate) }

      it 'updates the certs for the client config' do
        put :update,
            params: {
              client_id:, client_config: valid_attributes.merge(certs_attributes: [cert.attributes])
            }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response_body['certs']).to include(a_hash_including('id' => cert.id))
      end

      context 'when certs_attributes are empty' do
        it 'does not update the certs' do
          put :update, params: { client_id:, client_config: valid_attributes.merge(certs_attributes: []) }, as: :json

          expect(response).to have_http_status(:ok)
          expect(response_body['certs']).to be_empty
        end
      end

      context 'when certs_attributes contains _destroy' do
        let(:cert_to_destroy) { create(:sign_in_certificate) }

        before do
          client_config.certs << cert_to_destroy
        end

        it 'destroys the specified cert' do
          put :update, params: {
            client_id:,
            client_config: {
              certs_attributes: [{ id: cert_to_destroy.id, _destroy: '1' }]
            }
          }, as: :json

          expect(response).to have_http_status(:ok)
        end
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
          delete :destroy, params: { client_id: }
        end.to change(SignIn::ClientConfig, :count).by(-1)
      end
    end
  end
end
