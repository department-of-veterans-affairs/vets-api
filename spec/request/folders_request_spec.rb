# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'Folders Integration', type: :request do
  include SM::ClientHelpers
  include SchemaMatchers

  let(:user_id) { '10616687' }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_059 }
  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv, va_patient: va_patient, mhv_account_type: mhv_account_type) }
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
            post '/v0/messaging/health/folders', params: params
          end

          expect(response).to be_successful
          expect(response).to have_http_status(:created)
          expect(response).to match_response_schema('folder')
        end

        it 'response to POST #create with camel-inflection' do
          VCR.use_cassette('sm_client/folders/creates_a_folder_and_deletes_a_folder') do
            post '/v0/messaging/health/folders', params: params, headers: inflection_header
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
  end
end
