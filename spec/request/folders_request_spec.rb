# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

RSpec.describe 'Folders Integration', type: :request do
  include SM::ClientHelpers
  include SchemaMatchers

  let(:mhv_account) { double('mhv_account', ineligible?: false, needs_terms_acceptance?: false, accessible?: true) }
  let(:current_user) { build(:user, :mhv) }
  let(:user_id) { '10616687' }
  let(:inbox_id) { 0 }

  before(:each) do
    allow(MhvAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
    allow(SM::Client).to receive(:new).and_return(authenticated_client)
    use_authenticated_current_user(current_user: current_user)
  end

  describe '#index' do
    it 'responds to GET #index' do
      VCR.use_cassette('sm_client/folders/gets_a_collection_of_folders') do
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
        VCR.use_cassette('sm_client/folders/gets_a_single_folder') do
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
        VCR.use_cassette('sm_client/folders/creates_a_folder_and_deletes_a_folder') do
          post '/v0/messaging/health/folders', params
        end

        expect(response).to be_success
        expect(response).to have_http_status(:created)
        expect(response).to match_response_schema('folder')
      end
    end
  end

  describe '#destroy' do
    context 'with valid folder id' do
      let(:id) { 674_886 }

      it 'responds to DELETE #destroy' do
        VCR.use_cassette('sm_client/folders/creates_a_folder_and_deletes_a_folder') do
          delete "/v0/messaging/health/folders/#{id}"
        end

        expect(response).to be_success
        expect(response).to have_http_status(:no_content)
      end
    end
  end

  describe 'nested resources' do
    it 'gets messages#index' do
      VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages') do
        get "/v0/messaging/health/folders/#{inbox_id}/messages"
      end

      expect(response).to be_success
      expect(response).to have_http_status(:success)
      expect(response).to match_response_schema('messages')
    end
  end
end
