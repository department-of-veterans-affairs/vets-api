# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/helpers/mobile_sm_client_helper'

RSpec.describe 'Mobile Folders Integration', type: :request do
  include Mobile::MessagingClientHelper
  include SchemaMatchers

  let(:user_id) { '10616687' }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_059 }
  let(:va_patient) { true }

  before do
    allow_any_instance_of(MHVAccountTypeService).to receive(:mhv_account_type).and_return(mhv_account_type)
    allow(Mobile::V0::Messaging::Client).to receive(:new).and_return(authenticated_client)
    iam_sign_in(build(:iam_user, iam_mhv_id: '123'))
  end

  context 'Basic User' do
    let(:mhv_account_type) { 'Basic' }

    it 'is not authorized' do
      get '/mobile/v0/messaging/health/folders', headers: iam_headers
      expect(response).not_to be_successful
      expect(response.status).to eq(403)
    end
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }

    it 'is not authorized' do
      get '/mobile/v0/messaging/health/folders', headers: iam_headers
      expect(response).not_to be_successful
      expect(response.status).to eq(403)
    end
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

    describe '#index' do
      it 'responds to GET #index' do
        VCR.use_cassette('sm_client/folders/gets_a_collection_of_folders') do
          get '/mobile/v0/messaging/health/folders', headers: iam_headers
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('folders')
      end

      context 'when there are cached folders' do
        let(:user) { FactoryBot.build(:iam_user) }
        let(:params) { { useCache: true } }

        before do
          path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'folders.json')
          data = Common::Collection.new(Folder, data: JSON.parse(File.read(path)))
          Folder.set_cached("#{user.uuid}-folders", data)
        end

        it 'retrieve cached folders rather than hitting the service' do
          expect do
            get('/mobile/v0/messaging/health/folders', headers: iam_headers, params:)
            expect(response).to be_successful
            expect(response.body).to be_a(String)
            parsed_response_contents = response.parsed_body['data']
            folder = parsed_response_contents.select { |entry| entry['id'] == '-2' }[0]
            expect(folder.dig('attributes', 'name')).to eq('Drafts')
            expect(folder['type']).to eq('folders')
            expect(response).to match_camelized_response_schema('folders')
          end.to trigger_statsd_increment('mobile.sm.cache.hit', times: 1)
        end
      end

      it 'generates mobile-specific metadata links' do
        VCR.use_cassette('sm_client/folders/gets_a_collection_of_folders') do
          get '/mobile/v0/messaging/health/folders', headers: iam_headers
        end

        result = JSON.parse(response.body)
        folder = result['data'].first
        expect(folder['links']['self']).to match(%r{/mobile/v0})
        expect(result['links']['self']).to match(%r{/mobile/v0})
      end
    end

    describe '#show' do
      context 'with valid id' do
        it 'response to GET #show' do
          VCR.use_cassette('sm_client/folders/gets_a_single_folder') do
            get "/mobile/v0/messaging/health/folders/#{inbox_id}", headers: iam_headers
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
            post '/mobile/v0/messaging/health/folders', headers: iam_headers, params:
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
            delete "/mobile/v0/messaging/health/folders/#{id}", headers: iam_headers
          end

          expect(response).to be_successful
          expect(response).to have_http_status(:no_content)
        end
      end
    end

    describe 'nested resources' do
      it 'gets messages#index' do
        VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages') do
          get "/mobile/v0/messaging/health/folders/#{inbox_id}/messages", headers: iam_headers
        end

        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
        expect(response).to match_camelized_response_schema('messages')
      end

      context 'when there are cached folder messages' do
        let(:user) { FactoryBot.build(:iam_user) }
        let(:params) { { useCache: true } }

        before do
          path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'folder_messages.json')
          data = Common::Collection.new(Message, data: JSON.parse(File.read(path)))
          Message.set_cached("#{user.uuid}-folder-messages-#{inbox_id}", data)
        end

        it 'retrieve cached messages rather than hitting the service' do
          expect do
            get("/mobile/v0/messaging/health/folders/#{inbox_id}/messages", headers: iam_headers, params:)
            expect(response).to be_successful
            expect(response.body).to be_a(String)
            parsed_response_contents = response.parsed_body['data']
            message = parsed_response_contents.select { |entry| entry['id'] == '674220' }[0]
            expect(message.dig('attributes', 'category')).to eq('MEDICATIONS')
            expect(message['type']).to eq('messages')
            expect(response).to match_camelized_response_schema('messages')
          end.to trigger_statsd_increment('mobile.sm.cache.hit', times: 1)
        end
      end
    end
  end
end
