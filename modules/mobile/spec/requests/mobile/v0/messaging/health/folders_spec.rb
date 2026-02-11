# frozen_string_literal: true

require_relative '../../../../../support/helpers/rails_helper'
require 'vets/collection'
require 'unique_user_events'

RSpec.describe 'Mobile::V0::Messaging::Health::Folders', :skip_json_api_validation, type: :request do
  include SchemaMatchers

  let!(:user) { sis_user(:mhv, mhv_correlation_id: '123', mhv_account_type: 'Premium') }
  let(:inbox_id) { 0 }

  before do
    Timecop.freeze(Time.zone.parse('2017-05-01T19:25:00Z'))
  end

  after do
    Timecop.return
  end

  context 'when not authorized' do
    it 'responds with 403 error' do
      VCR.use_cassette('mobile/messages/session_error') do
        get '/mobile/v0/messaging/health/folders', headers: sis_headers
      end
      expect(response).not_to be_successful
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when authorized' do
    before do
      VCR.insert_cassette('sm_client/session')
      allow_any_instance_of(SM::Client).to receive(:get_triage_teams_station_numbers).and_return([])
    end

    after do
      VCR.eject_cassette
    end

    describe '#index' do
      it 'responds to GET #index' do
        VCR.use_cassette('sm_client/folders/gets_a_collection_of_folders') do
          get '/mobile/v0/messaging/health/folders', headers: sis_headers
        end
        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('folders')
        expect(response.parsed_body['data'].size).to eq(11)
        expect(response.parsed_body.dig('meta', 'pagination', 'perPage')).to eq(100)
      end

      context 'when there are pagination parameters' do
        it 'returns expected number of pages and items per pages' do
          VCR.use_cassette('sm_client/folders/gets_a_collection_of_folders') do
            get '/mobile/v0/messaging/health/folders', params: { page: 3, per_page: 5 }, headers: sis_headers
          end
          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response).to match_camelized_response_schema('folders')
          expect(response.parsed_body['data'].size).to eq(1)
          expect(response.parsed_body.dig('meta', 'pagination', 'currentPage')).to eq(3)
          expect(response.parsed_body.dig('meta', 'pagination', 'perPage')).to eq(5)
          expect(response.parsed_body.dig('meta', 'pagination', 'totalPages')).to eq(3)
          expect(response.parsed_body.dig('meta', 'pagination', 'totalEntries')).to eq(11)
        end
      end

      context 'when there are cached folders' do
        let(:params) { { useCache: true } }

        before do
          path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'folders.json')
          data = Vets::Collection.new(JSON.parse(File.read(path)), Folder)
          Folder.set_cached("#{user.uuid}-folders", data.records)
        end

        it 'retrieve cached folders rather than hitting the service' do
          expect do
            get('/mobile/v0/messaging/health/folders', headers: sis_headers, params:)
            expect(response).to be_successful
            expect(response.body).to be_a(String)
            parsed_response_contents = response.parsed_body['data']
            folder = parsed_response_contents.select { |entry| entry['id'] == '-2' }[0]
            expect(folder.dig('attributes', 'name')).to eq('Drafts')
            expect(folder['type']).to eq('folders')
            expect(response).to match_camelized_response_schema('folders')
          end.to trigger_statsd_increment('mhv.sm.api.client.cache.hit', times: 1)
        end
      end

      it 'generates mobile-specific metadata links' do
        VCR.use_cassette('sm_client/folders/gets_a_collection_of_folders') do
          get '/mobile/v0/messaging/health/folders', headers: sis_headers
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
            get "/mobile/v0/messaging/health/folders/#{inbox_id}", headers: sis_headers
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response).to match_camelized_response_schema('folder')
          link = response.parsed_body.dig('data', 'links', 'self')
          expect(link).to eq('http://www.example.com/mobile/v0/messaging/health/folders/0')
        end
      end
    end

    describe '#create' do
      context 'with valid name' do
        let(:params) { { folder: { name: 'test folder create name 160805101218' } } }

        it 'response to POST #create' do
          VCR.use_cassette('sm_client/folders/creates_a_folder_and_deletes_a_folder') do
            post '/mobile/v0/messaging/health/folders', headers: sis_headers, params:
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
            delete "/mobile/v0/messaging/health/folders/#{id}", headers: sis_headers
          end

          expect(response).to be_successful
          expect(response).to have_http_status(:no_content)
        end
      end
    end

    describe 'nested resources' do
      it 'gets messages#index' do
        allow(UniqueUserEvents).to receive(:log_event)
        VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages') do
          get "/mobile/v0/messaging/health/folders/#{inbox_id}/messages", headers: sis_headers
        end
        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
        expect(response).to match_camelized_response_schema('messages')
        expect(response.parsed_body['data'].size).to eq(10)
        expect(response.parsed_body.dig('meta', 'pagination', 'totalEntries')).to eq(10)

        # Verify event logging was called
        expect(UniqueUserEvents).to have_received(:log_event).with(
          user: anything,
          event_name: UniqueUserEvents::EventRegistry::SECURE_MESSAGING_INBOX_ACCESSED
        )
      end

      context 'when the OH flag is true' do
        it 'returns expected number of pages and items per pages' do
          allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_cerner_pilot, anything).and_return(true)
          VCR.use_cassette('sm_client/session_require_oh') do
            VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages_with_OH') do
              get "/mobile/v0/messaging/health/folders/#{inbox_id}/messages", headers: sis_headers
            end
          end
          expect(response).to be_successful
          expect(response).to have_http_status(:ok)
          expect(response).to match_camelized_response_schema('messages')
          expect(response.parsed_body['data'].size).to eq(10)
          expect(response.parsed_body.dig('meta', 'pagination', 'totalEntries')).to eq(10)
        end
      end

      context 'when there are cached folder messages' do
        let(:params) { { useCache: true } }

        before do
          path = Rails.root.join('modules', 'mobile', 'spec', 'support', 'fixtures', 'folder_messages.json')
          data = Vets::Collection.new(JSON.parse(File.read(path)), Message)
          Message.set_cached("#{user.uuid}-folder-messages-#{inbox_id}", data.records)
        end

        it 'retrieve cached messages rather than hitting the service' do
          expect do
            get("/mobile/v0/messaging/health/folders/#{inbox_id}/messages", headers: sis_headers, params:)
            expect(response).to be_successful
            expect(response.body).to be_a(String)
            parsed_response_contents = response.parsed_body['data']
            message = parsed_response_contents.select { |entry| entry['id'] == '674220' }[0]
            expect(message.dig('attributes', 'category')).to eq('MEDICATIONS')
            expect(message['type']).to eq('messages')
            expect(response).to match_camelized_response_schema('messages')
          end.to trigger_statsd_increment('mhv.sm.api.client.cache.hit', times: 1)
        end
      end

      it 'shows a count of read and unread' do
        VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages') do
          get "/mobile/v0/messaging/health/folders/#{inbox_id}/messages", headers: sis_headers
        end

        expect(response.parsed_body.dig('meta', 'messageCounts', 'read')).to eq(6)
        expect(response.parsed_body.dig('meta', 'messageCounts', 'unread')).to eq(4)
      end
    end
  end
end
