# frozen_string_literal: true

require 'rails_helper'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V1::Messaging::Folders', type: :request do
  include SM::ClientHelpers
  include SchemaMatchers

  let(:user_id) { '10616687' }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_059 }
  let(:current_user) { build(:user, :mhv) }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  before do
    sign_in_as(current_user)
    Timecop.freeze(Time.zone.parse('2017-05-01T19:25:00Z'))
  end

  after do
    Timecop.return
  end

  context 'when NOT authorized' do
    before do
      VCR.insert_cassette('sm_client/session_error')
      get '/my_health/v1/messaging/folders'
    end

    after do
      VCR.eject_cassette
    end

    include_examples 'for user account level', message: 'You do not have access to messaging'
  end

  context 'when authorized' do
    before do
      allow(SM::Client).to receive(:new).and_return(authenticated_client)
      VCR.insert_cassette('sm_client/session')
    end

    after do
      VCR.eject_cassette
    end

    describe '#index' do
      it 'responds to GET #index' do
        VCR.use_cassette('sm_client/folders/gets_a_collection_of_folders') do
          get '/my_health/v1/messaging/folders', params: { page: 3, per_page: 5 }
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('my_health/messaging/v1/folders')
      end

      it 'responds to GET #index when camel-inflected' do
        VCR.use_cassette('sm_client/folders/gets_a_collection_of_folders') do
          get '/my_health/v1/messaging/folders', headers: inflection_header, params: { page: 3, per_page: 5 }
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('my_health/messaging/v1/folders')
      end

      it 'responds to GET #index when requires_oh_messages param is provided' do
        VCR.use_cassette('sm_client/folders/gets_a_collection_of_folders_with_oh_messages') do
          get '/my_health/v1/messaging/folders?requires_oh_messages=1', headers: inflection_header
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('my_health/messaging/v1/folders')
      end
    end

    describe '#show' do
      context 'with valid id' do
        it 'response to GET #show' do
          VCR.use_cassette('sm_client/folders/gets_a_single_folder') do
            get "/my_health/v1/messaging/folders/#{inbox_id}"
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('my_health/messaging/v1/folder')
        end

        it 'response to GET #show when camel-inflected' do
          VCR.use_cassette('sm_client/folders/gets_a_single_folder') do
            get "/my_health/v1/messaging/folders/#{inbox_id}", headers: inflection_header
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response).to match_camelized_response_schema('my_health/messaging/v1/folder')
        end

        it 'response to GET #show when requires_oh_messages parameter is provided' do
          VCR.use_cassette('sm_client/folders/gets_a_single_folder_oh_messages') do
            get "/my_health/v1/messaging/folders/#{inbox_id}?requires_oh_messages=1"
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('my_health/messaging/v1/folder')
        end
      end
    end

    describe '#create' do
      context 'with valid name' do
        let(:params) { { folder: { name: 'test folder create name 160805101218' } } }

        it 'response to POST #create' do
          VCR.use_cassette('sm_client/folders/creates_a_folder_and_deletes_a_folder') do
            post '/my_health/v1/messaging/folders', params:
          end

          expect(response).to be_successful
          expect(response).to have_http_status(:created)
          expect(response).to match_response_schema('my_health/messaging/v1/folder')
        end

        it 'response to POST #create with camel-inflection' do
          VCR.use_cassette('sm_client/folders/creates_a_folder_and_deletes_a_folder') do
            post '/my_health/v1/messaging/folders', params:, headers: inflection_header
          end

          expect(response).to be_successful
          expect(response).to have_http_status(:created)
          expect(response).to match_camelized_response_schema('my_health/messaging/v1/folder')
        end
      end
    end

    describe '#update' do
      context 'with valid folder id' do
        let(:id) { 7_207_029 }
        let(:params) { { folder: { name: 'Test222' } } }

        it 'responds to RENAME #update' do
          VCR.use_cassette('sm_client/folders/renames_a_folder') do
            put "/my_health/v1/messaging/folders/#{id}", params:
          end

          expect(response).to be_successful
          expect(response).to have_http_status(:created)
          expect(response).to match_response_schema('my_health/messaging/v1/folder')
        end
      end
    end

    describe '#destroy' do
      context 'with valid folder id' do
        let(:id) { 674_886 }

        it 'responds to DELETE #destroy' do
          VCR.use_cassette('sm_client/folders/creates_a_folder_and_deletes_a_folder') do
            delete "/my_health/v1/messaging/folders/#{id}"
          end

          expect(response).to be_successful
          expect(response).to have_http_status(:no_content)
        end
      end
    end

    describe '#search' do
      context 'with valid search criteria' do
        let(:id) { 0 }

        it 'responds to POST #search' do
          VCR.use_cassette('sm_client/folders/searches_a_folder') do
            post "/my_health/v1/messaging/folders/#{id}/search", params: { subject: 'test' }
          end

          expect(response).to be_successful
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('my_health/messaging/v1/folder_search')
        end

        it 'responds to POST #search when requires_oh_messages parameter is provided' do
          VCR.use_cassette('sm_client/folders/searches_a_folder_oh_messages') do
            post "/my_health/v1/messaging/folders/#{id}/search?requires_oh_messages=1", params: { subject: 'THREAD' }
          end

          expect(response).to be_successful
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('my_health/messaging/v1/folder_search')
        end
      end
    end

    describe 'nested resources' do
      it 'gets messages#index' do
        VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages') do
          get "/my_health/v1/messaging/folders/#{inbox_id}/messages"
        end

        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('my_health/messaging/v1/messages')
      end

      it 'gets messages#index with camel-inflection' do
        VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages') do
          get "/my_health/v1/messaging/folders/#{inbox_id}/messages", headers: inflection_header
        end

        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
        expect(response).to match_camelized_response_schema('my_health/messaging/v1/messages')
      end
    end

    describe 'pagination' do
      it 'provides pagination indicators' do
        VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages') do
          get "/my_health/v1/messaging/folders/#{inbox_id}/messages"
        end

        payload = JSON.parse(response.body)
        pagination = payload['meta']['pagination']
        expect(pagination['total_entries']).to eq(10)
      end

      it 'respects pagination parameters' do
        VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages') do
          get "/my_health/v1/messaging/folders/#{inbox_id}/messages", params: { page: 2, per_page: 3 }
        end

        payload = JSON.parse(response.body)
        pagination = payload['meta']['pagination']
        expect(pagination['current_page']).to eq(2)
        expect(pagination['per_page']).to eq(3)
        expect(pagination['total_pages']).to eq(4)
        expect(pagination['total_entries']).to eq(10)
      end

      it 'does not paginate if per_page pagination parameter is -1' do
        VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages') do
          get "/my_health/v1/messaging/folders/#{inbox_id}/messages", params: { per_page: -1 }
        end

        payload = JSON.parse(response.body)
        pagination = payload['meta']['pagination']
        expect(pagination).to be_nil
      end

      it 'generates a 4xx error for out of bounds pagination' do
        VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages') do
          get "/my_health/v1/messaging/folders/#{inbox_id}/messages", params: { page: 3, per_page: 10 }
        end
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
