# frozen_string_literal: true

require 'rails_helper'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'V0::Messaging::Health::Folders', type: :request do
  include SM::ClientHelpers
  include SchemaMatchers

  let(:user_id) { '10616687' }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_059 }
  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv, va_patient:, mhv_account_type:) }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  before do
    allow(SM::Client).to receive(:new).and_return(authenticated_client)
    sign_in_as(current_user)
  end

  context 'Basic User' do
    let(:mhv_account_type) { 'Basic' }

    before { get '/v0/messaging/health/folders' }

    include_examples 'for user account level', message: 'You do not have access to messaging'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }

    before { get '/v0/messaging/health/folders' }

    include_examples 'for user account level', message: 'You do not have access to messaging'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

    context 'not a va patient' do
      before { get '/v0/messaging/health/folders' }

      let(:va_patient) { false }
      let(:current_user) do
        build(:user, :mhv, :no_vha_facilities, va_patient:, mhv_account_type:)
      end

      include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
    end

    describe '#index' do
      it 'responds to GET #index' do
        VCR.use_cassette('sm_client/folders/gets_a_collection_of_folders') do
          get '/v0/messaging/health/folders'
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('folders')
      end

      it 'responds to GET #index when camel-inflected' do
        VCR.use_cassette('sm_client/folders/gets_a_collection_of_folders') do
          get '/v0/messaging/health/folders', headers: inflection_header
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('folders')
      end
    end

    describe '#show' do
      context 'with valid id' do
        it 'response to GET #show' do
          VCR.use_cassette('sm_client/folders/gets_a_single_folder') do
            get "/v0/messaging/health/folders/#{inbox_id}"
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('folder')
        end

        it 'response to GET #show when camel-inflected' do
          VCR.use_cassette('sm_client/folders/gets_a_single_folder') do
            get "/v0/messaging/health/folders/#{inbox_id}", headers: inflection_header
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response).to match_camelized_response_schema('folder')
        end
      end
    end

    describe '#create' do
      context 'with valid name' do
        let(:params) { { folder: { name: 'test folder create name 160805101218' } } }

        it 'response to POST #create' do
          VCR.use_cassette('sm_client/folders/creates_a_folder_and_deletes_a_folder') do
            post '/v0/messaging/health/folders', params:
          end

          expect(response).to be_successful
          expect(response).to have_http_status(:created)
          expect(response).to match_response_schema('folder')
        end

        it 'response to POST #create with camel-inflection' do
          VCR.use_cassette('sm_client/folders/creates_a_folder_and_deletes_a_folder') do
            post '/v0/messaging/health/folders', params:, headers: inflection_header
          end

          expect(response).to be_successful
          expect(response).to have_http_status(:created)
          expect(response).to match_camelized_response_schema('folder')
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

          expect(response).to be_successful
          expect(response).to have_http_status(:no_content)
        end
      end
    end

    describe 'nested resources' do
      it 'gets messages#index' do
        VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages') do
          get "/v0/messaging/health/folders/#{inbox_id}/messages"
        end
        binding.pry
        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('messages')
      end

      it 'gets messages#index with camel-inflection' do
        VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages') do
          get "/v0/messaging/health/folders/#{inbox_id}/messages", headers: inflection_header
        end

        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
        expect(response).to match_camelized_response_schema('messages')
      end
    end

    describe 'pagination' do
      it 'provides pagination indicators' do
        VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages') do
          get "/v0/messaging/health/folders/#{inbox_id}/messages"
        end

        payload = JSON.parse(response.body)
        pagination = payload['meta']['pagination']
        expect(pagination['total_entries']).to eq(10)
      end

      it 'respects pagination parameters' do
        VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages') do
          get "/v0/messaging/health/folders/#{inbox_id}/messages", params: { page: 2, per_page: 3 }
        end

        payload = JSON.parse(response.body)
        pagination = payload['meta']['pagination']
        expect(pagination['current_page']).to eq(2)
        expect(pagination['per_page']).to eq(3)
        expect(pagination['total_pages']).to eq(4)
        expect(pagination['total_entries']).to eq(10)
      end

      it 'generates a 4xx error for out of bounds pagination' do
        VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages') do
          get "/v0/messaging/health/folders/#{inbox_id}/messages", params: { page: 3, per_page: 10 }
        end
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
