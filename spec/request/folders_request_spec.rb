# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

RSpec.describe 'Folders Integration', type: :request do
  include SM::ClientHelpers

  before(:each) do
    allow_any_instance_of(ApplicationController).to receive(:authenticate).and_return(true)
    expect(SM::Client).to receive(:new).once.and_return(authenticated_client)
  end

  let(:user_id) { ENV['MHV_SM_USER_ID'] }
  let(:inbox_id) { 0 }

  describe '#index' do
    it 'responds to GET #index' do
      VCR.use_cassette("sm/folders/#{user_id}/index") do
        get '/v0/messaging/health/folders'
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('folders')
    end
  end

  describe '#show' do
    context 'with valid id' do
      it 'response to GET #show' do
        VCR.use_cassette("sm/folders/#{user_id}/show") do
          get "/v0/messaging/health/folders/#{inbox_id}"
        end

        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('folder')
      end
    end
  end

  describe '#create' do
    context 'with valid name' do
      let(:params) { { folder: { name: 'test folder create name 160805101218' } } }

      it 'response to POST #create' do
        VCR.use_cassette("sm/folders/#{user_id}/create_valid") do
          post '/v0/messaging/health/folders', params
        end

        expect(response).to be_success
        expect(response).to have_http_status(:created)
        expect(response).to match_response_schema('folder')
      end
    end

    context 'with name that has been taken' do
      let(:params) { { folder: { name: 'a valid name 123' } } }

      it 'response to POST #create' do
        VCR.use_cassette("sm/folders/#{user_id}/create_fail_name_taken") do
          post '/v0/messaging/health/folders', params
        end
        expect(response).to have_http_status(:bad_request)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['errors'][0]['detail'])
          .to eq('The folder already exists with the requested name')
      end
    end
  end

  describe '#destroy' do
    context 'with valid folder id' do
      let(:id) { 613_557 }

      it 'response to DELETE #destroy' do
        VCR.use_cassette("sm/folders/#{user_id}/delete_valid") do
          delete "/v0/messaging/health/folders/#{id}"
        end

        expect(response).to be_success
        expect(response).to have_http_status(:no_content)
      end
    end

    context 'with non-existing id' do
      let(:id) { -1 }

      it 'response to DELETE #destroy' do
        VCR.use_cassette("sm/folders/#{user_id}/delete_fail_system_folder") do
          delete "/v0/messaging/health/folders/#{id}"
        end

        expect(response).to have_http_status(:bad_request)
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['errors'][0]['detail'])
          .to eq('Entity not found')
      end
    end
  end
end
