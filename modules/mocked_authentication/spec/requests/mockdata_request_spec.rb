# frozen_string_literal: true

require 'rails_helper'
require 'mockdata/mpi/find'

RSpec.describe 'Mocked authentication mpi mockdata', type: :request do
  let(:icn) { '12345' }
  let(:yml) { 'some-yml-content' }
  let(:api_key) { 'some-api-key' }
  let(:auth_header) { "Bearer #{api_key}" }

  describe 'GET #show' do
    before do
      allow(Settings.sign_in).to receive(:mockdata_sync_api_key).and_return(api_key)
    end

    context 'when icn is present and api_key is valid' do
      before do
        allow(MockedAuthentication::Mockdata::MPI::Find)
          .to receive(:new)
          .with(icn:)
          .and_return(instance_double(MockedAuthentication::Mockdata::MPI::Find, perform: yml))
      end

      it 'returns a success status and yml data' do
        get "/mocked_authentication/mpi/mockdata/#{icn}", headers: { 'Authorization' => auth_header }

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)['data']['attributes']).to include('icn' => icn, 'yml' => yml)
      end
    end

    context 'when icn is missing' do
      it 'returns a 404' do
        get '/mocked_authentication/mpi/mockdata/', headers: { 'Authorization' => auth_header }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when authorization is invalid' do
      let(:auth_header) { 'Bearer bad-key' }

      it 'returns an unauthorized status' do
        get "/mocked_authentication/mpi/mockdata/#{icn}", headers: { 'Authorization' => auth_header }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when there is no authorization header' do
      it 'returns an unauthorized status' do
        get "/mocked_authentication/mpi/mockdata/#{icn}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
