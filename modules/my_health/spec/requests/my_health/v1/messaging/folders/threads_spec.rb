# frozen_string_literal: true

require 'rails_helper'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V1::Messaging::Folders::Threads', type: :request do
  include SM::ClientHelpers
  include SchemaMatchers

  let(:user_id) { '10616687' }
  let(:inbox_id) { 0 }
  let(:message_id) { 660_516 }
  let(:thread_id) { 660_515 }
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
      get "/my_health/v1/messaging/folders/#{inbox_id}/threads"
    end

    after do
      VCR.eject_cassette
    end

    include_examples 'for user account level', message: 'You do not have access to messaging'
  end

  context 'when authorized' do
    before do
      VCR.insert_cassette('sm_client/session')
    end

    after do
      VCR.eject_cassette
    end

    describe '#index' do
      context 'with valid params' do
        it 'responds to GET #index' do
          allow(UniqueUserEvents).to receive(:log_event)

          VCR.use_cassette('sm_client/threads/gets_threads_in_a_folder') do
            get "/my_health/v1/messaging/folders/#{inbox_id}/threads",
                params: { page_size: '5', page_number: '1', sort_field: 'SENDER_NAME', sort_order: 'ASC' }
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('my_health/messaging/v1/message_threads')

          # Verify event logging was called
          expect(UniqueUserEvents).to have_received(:log_event).with(
            user: anything,
            event_name: UniqueUserEvents::EventRegistry::SECURE_MESSAGING_INBOX_ACCESSED
          )
        end

        it 'responds to GET #index when camel-inflected' do
          VCR.use_cassette('sm_client/threads/gets_threads_in_a_folder_camel') do
            get "/my_health/v1/messaging/folders/#{inbox_id}/threads",
                params: { page_size: '5', page_number: '1', sort_field: 'SENDER_NAME', sort_order: 'ASC' },
                headers: { 'X-Key-Inflection' => 'camel' }
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response).to match_camelized_response_schema('my_health/messaging/v1/message_threads')
        end

        it 'returns an empty array when there are no messages in the folder with error response (old)' do
          allow(Rails.logger).to receive(:info)
          VCR.use_cassette('sm_client/threads/gets_threads_in_a_folder_no_messages') do
            get "/my_health/v1/messaging/folders/#{inbox_id}/threads",
                params: { page_size: '5', page_number: '1', sort_field: 'SENDER_NAME', sort_order: 'ASC' }
          end

          expect(Rails.logger).to have_received(:info).with(
            an_object_having_attributes(
              detail: 'No messages in the requested folder',
              code: 'SM915',
              status: '400',
              title: 'Operation failed'
            )
          )
          expect(response).to be_successful

          json_response = JSON.parse(response.body)
          expect(json_response).to eq({ 'data' => [] })
          expect(response).to match_response_schema('my_health/messaging/v1/message_threads_no_messages')
        end

        it 'returns an empty array when there are no messages in the folder with empty array response(new)' do
          VCR.use_cassette('sm_client/threads/gets_threads_in_a_folder_no_messages_empty_array') do
            get "/my_health/v1/messaging/folders/#{inbox_id}/threads",
                params: { page_size: '5', page_number: '1', sort_field: 'SENDER_NAME', sort_order: 'ASC' }
          end

          expect(response).to be_successful

          json_response = JSON.parse(response.body)
          expect(json_response).to eq({ 'data' => [] })
          expect(response).to match_response_schema('my_health/messaging/v1/message_threads_no_messages')
        end

        context 'when Breakers::OutageException is raised' do
          let(:mock_service) { instance_double(Breakers::Service, name: 'SM') }
          let(:mock_outage) do
            instance_double(Breakers::Outage, start_time: Time.zone.now, end_time: nil, service: mock_service)
          end
          let(:mock_exception) { Breakers::OutageException.new(mock_outage, mock_service) }

          before do
            allow_any_instance_of(SM::Client).to receive(:get_folder_threads).and_raise(mock_exception)
            allow(StatsD).to receive(:increment)
          end

          it 'returns a 503 status code' do
            get "/my_health/v1/messaging/folders/#{inbox_id}/threads",
                params: { page_size: '5', page_number: '1', sort_field: 'SENDER_NAME', sort_order: 'ASC' }

            expect(response).to have_http_status(:service_unavailable)
            expect(StatsD).to have_received(:increment).with('api.my_health.threads.fail')
          end
        end
      end
    end

    describe '#move' do
      let(:thread_id) { 7_065_799 }

      it 'responds to PATCH threads/move' do
        VCR.use_cassette('sm_client/threads/moves_a_thread_with_id') do
          patch "/my_health/v1/messaging/threads/#{thread_id}/move?folder_id=0"
        end

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
      end

      it 'responds with error to PATCH threads/move with invalid thread id' do
        VCR.use_cassette('sm_client/threads/moves_a_thread_with_invalid_thread_id') do
          patch '/my_health/v1/messaging/threads/123/move?folder_id=0'
        end
        json_response = JSON.parse(response.body)['errors'].first
        expect(json_response['code']).to eq('SM115')
      end

      it 'responds with error to PATCH threads/move with invalid folder id' do
        VCR.use_cassette('sm_client/threads/moves_a_thread_with_invalid_folder_id') do
          patch '/my_health/v1/messaging/threads/3470562/move?folder_id=123'
        end

        json_response = JSON.parse(response.body)['errors'].first
        expect(json_response['detail']).to eq("Folder Doesn't exists")
      end
    end
  end

  context 'with requires_oh flag enabled' do
    it 'responds to GET #index when requires_oh_messages flipper is provided' do
      allow(Flipper).to receive(:enabled?)
        .with(:mhv_secure_messaging_cerner_pilot, anything)
        .and_return(true)

      VCR.use_cassette('sm_client/session_require_oh') do
        VCR.use_cassette('sm_client/threads/gets_threads_in_a_folder_oh_messages') do
          get "/my_health/v1/messaging/folders/#{inbox_id}/threads",
              params: { page_size: '5', page_number: '1', sort_field: 'SENDER_NAME', sort_order: 'ASC' }
        end
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
    end
  end
end
