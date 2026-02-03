# frozen_string_literal: true

require_relative '../../../../../support/helpers/rails_helper'
require 'unique_user_events'

RSpec.describe 'Mobile::V0::Messaging::Health::Messages', type: :request do
  include SchemaMatchers

  let!(:user) { sis_user(:mhv, mhv_account_type: 'Premium') }
  let(:message_id) { 573_059 }

  before { Timecop.freeze(Time.zone.parse('2017-05-01T19:25:00Z')) }

  after do
    Timecop.return
  end

  context 'when user does not have access' do
    let!(:user) { sis_user(:mhv, mhv_correlation_id: nil) }

    it 'returns forbidden' do
      get '/mobile/v0/messaging/health/messages/categories', headers: sis_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when not authorized' do
    it 'responds with 403 error' do
      VCR.use_cassette('mobile/messages/session_error') do
        get '/mobile/v0/messaging/health/messages/categories', headers: sis_headers
      end
      expect(response).not_to be_successful
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when authorized' do
    before do
      VCR.insert_cassette('sm_client/session')
    end

    after do
      VCR.eject_cassette
    end

    context 'with authorization to use service' do
      it 'responds to GET messages/categories' do
        VCR.use_cassette('sm_client/messages/gets_message_categories') do
          get '/mobile/v0/messaging/health/messages/categories', headers: sis_headers
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('category')
      end

      it 'responds to GET #show with inactive triage group' do
        VCR.use_cassette('mobile/messages/gets_a_message_with_id_and_attachment') do
          VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients') do
            get "/mobile/v0/messaging/health/messages/#{message_id}", headers: sis_headers
          end
        end
        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response.parsed_body['meta']['userInTriageTeam']).to be(false)
        expect(response).to match_camelized_response_schema('message', strict: false)
        link = response.parsed_body.dig('data', 'links', 'self')
        expect(link).to eq('http://www.example.com/mobile/v0/messaging/health/messages/573059')
        included = response.parsed_body.dig('included', 0)
        expect(included).to eq({ 'id' => '674847',
                                 'type' => 'attachments',
                                 'attributes' => { 'name' => 'sm_file1.jpg',
                                                   'messageId' => 573_059,
                                                   'attachmentSize' => 210_000 },
                                 'links' => { 'download' => 'http://www.example.com/mobile/v0/messaging' \
                                                            '/health/messages/573059/attachments/674847' } })
      end

      it 'responds to GET #show with active triage group' do
        VCR.use_cassette('mobile/messages/gets_a_message_active_triage_team') do
          VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients') do
            get "/mobile/v0/messaging/health/messages/#{message_id}", headers: sis_headers
          end
        end
        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response.parsed_body['meta']['userInTriageTeam']).to be(true)
        expect(response).to match_camelized_response_schema('message', strict: false)
      end

      it 'returns message signature preferences' do
        VCR.use_cassette('sm_client/messages/gets_message_signature') do
          get '/mobile/v0/messaging/health/messages/signature', headers: sis_headers
        end

        result = JSON.parse(response.body)
        expect(result['data']['attributes']['signatureName']).to eq('test-api Name')
        expect(result['data']['attributes']['includeSignature']).to be(true)
        expect(result['data']['attributes']['signatureTitle']).to eq('test-api title')
      end

      context 'when signature prefs are empty' do
        it 'returns empty message signature preferences' do
          VCR.use_cassette('sm_client/messages/gets_empty_message_signature') do
            get '/mobile/v0/messaging/health/messages/signature', headers: sis_headers
          end

          result = JSON.parse(response.body)
          expect(result['data']['attributes']['signatureName']).to be_nil
          expect(result['data']['attributes']['includeSignature']).to be(false)
          expect(result['data']['attributes']['signatureTitle']).to be_nil
        end
      end

      describe 'POST create' do
        let(:attachment_type) { 'image/jpg' }
        let(:uploads) do
          [
            Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1.jpg', attachment_type),
            Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file2.jpg', attachment_type),
            Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file3.jpg', attachment_type),
            Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file4.jpg', attachment_type)
          ]
        end
        let(:message_params) { attributes_for(:message, subject: 'CI Run', body: 'Continuous Integration') }
        let(:params) { message_params.slice(:subject, :category, :recipient_id, :body) }
        let(:params_with_station) { params.merge(station_number: '979') }
        let(:params_with_attachments) { { message: params }.merge(uploads:) }

        context 'message' do
          it 'without attachments' do
            allow(UniqueUserEvents).to receive(:log_event)

            VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments') do
              post '/mobile/v0/messaging/health/messages', headers: sis_headers,
                                                           params: { message: params_with_station }
            end

            expect(response).to be_successful
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
            expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
            expect(response).to match_camelized_response_schema('message', strict: false)
            included = response.parsed_body.dig('included', 0)
            expect(included).to be_nil

            # Verify event logging was called with facility ID from station_number param
            expect(UniqueUserEvents).to have_received(:log_event).with(
              user: anything,
              event_name: UniqueUserEvents::EventRegistry::SECURE_MESSAGING_MESSAGE_SENT,
              event_facility_ids: ['979']
            )
          end

          it 'with attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_new_message_with_4_attachments') do
              post '/mobile/v0/messaging/health/messages', headers: sis_headers, params: params_with_attachments
            end

            expect(response).to be_successful
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
            expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
            expect(response).to match_camelized_response_schema('message_with_attachment')
            link = response.parsed_body.dig('data', 'links', 'self')
            expect(link).to eq('http://www.example.com/mobile/v0/messaging/health/messages/674852')
          end

          it 'without station_number omits facility tracking' do
            allow(UniqueUserEvents).to receive(:log_event)

            VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments') do
              post '/mobile/v0/messaging/health/messages', headers: sis_headers,
                                                           params: { message: params }
            end

            expect(response).to be_successful

            # Verify event logging was called with empty facility IDs when station_number not provided
            expect(UniqueUserEvents).to have_received(:log_event).with(
              user: anything,
              event_name: UniqueUserEvents::EventRegistry::SECURE_MESSAGING_MESSAGE_SENT,
              event_facility_ids: []
            )
          end

          it 'logs and re-raises serialization errors on create with attachments' do
            error = Common::Client::Errors::Serialization.new(status: 500, body: 'bad response', message: 'parse error')
            allow_any_instance_of(Mobile::V0::Messaging::Client)
              .to receive(:post_create_message_with_attachment).and_raise(error)

            allow(Rails.logger).to receive(:info)
            expect(Rails.logger).to receive(:info).with(
              'Mobile SM create with attachment error',
              hash_including(:status, :error_body, :message)
            )

            post '/mobile/v0/messaging/health/messages', headers: sis_headers, params: params_with_attachments

            expect(response).not_to be_successful
          end
        end

        context 'reply' do
          let(:reply_message_id) { 674_838 }

          it 'without attachments' do
            allow(UniqueUserEvents).to receive(:log_event)

            VCR.use_cassette('sm_client/messages/creates/a_reply_without_attachments') do
              post "/mobile/v0/messaging/health/messages/#{reply_message_id}/reply",
                   headers: sis_headers, params: { message: params_with_station }
            end

            expect(response).to be_successful
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
            expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
            expect(response).to match_camelized_response_schema('message', strict: false)

            # Verify event logging was called with facility ID from station_number param
            expect(UniqueUserEvents).to have_received(:log_event).with(
              user: anything,
              event_name: UniqueUserEvents::EventRegistry::SECURE_MESSAGING_MESSAGE_SENT,
              event_facility_ids: ['979']
            )
          end

          it 'with attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_reply_with_4_attachments') do
              post "/mobile/v0/messaging/health/messages/#{reply_message_id}/reply",
                   headers: sis_headers, params: params_with_attachments
            end

            expect(response).to be_successful
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
            expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
            expect(JSON.parse(response.body)['included'][0]['attributes']['attachment_size']).to be_positive.or be_nil
            expect(response).to match_camelized_response_schema('message_with_attachment')
          end
        end

        context 'poll_for_status parameter' do
          let(:attachment_type) { 'image/jpg' }
          let(:uploads) { [Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1.jpg', attachment_type)] }
          let(:message_params) { attributes_for(:message, subject: 'OH Group Subject', body: 'Body') }
          let(:params) { message_params.slice(:subject, :category, :recipient_id, :body) }
          let(:params_with_attachments) { { message: params, uploads: } }

          it 'passes poll_for_status=true on create with attachments when is_oh_triage_group=true' do
            expect_any_instance_of(Mobile::V0::Messaging::Client)
              .to receive(:post_create_message_with_attachment)
              .with(kind_of(Hash), is_oh: true)
              .and_return(build(:message, attachment: true, attachments: build_list(:attachment, 1)))

            post '/mobile/v0/messaging/health/messages?is_oh_triage_group=true',
                 headers: sis_headers,
                 params: params_with_attachments

            expect(response).to be_successful
          end

          it 'passes poll_for_status=true on reply without attachments when is_oh_triage_group=true' do
            expect_any_instance_of(Mobile::V0::Messaging::Client).to receive(:poll_message_status)
              .and_return({ status: 'SENT' })
            VCR.use_cassette('sm_client/messages/creates/a_reply_without_attachments') do
              post '/mobile/v0/messaging/health/messages/674838/reply?is_oh_triage_group=true',
                   headers: sis_headers,
                   params: { message: params }
            end

            expect(response).to be_successful
          end
        end

        context 'multipart form data with is_oh_triage_group inside stringified JSON message' do
          # This tests the fix for the mobile app behavior where multipart/form-data requests
          # send `message` as a JSON string containing `is_oh_triage_group` inside it,
          # rather than as a separate top-level form field or query parameter.
          let(:attachment_type) { 'image/jpg' }
          let(:uploads) { [Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1.jpg', attachment_type)] }
          let(:message_params) { attributes_for(:message, subject: 'OH Multipart Test', body: 'Body') }

          it 'correctly detects is_oh_triage_group when inside stringified JSON on create with attachments' do
            # Simulate mobile app behavior: message is a JSON string with is_oh_triage_group inside
            message_with_oh_flag = message_params.slice(:subject, :category, :recipient_id, :body)
                                                 .merge(is_oh_triage_group: true)
            stringified_message = message_with_oh_flag.to_json

            expect_any_instance_of(Mobile::V0::Messaging::Client)
              .to receive(:post_create_message_with_attachment)
              .with(kind_of(Hash), is_oh: true)
              .and_return(build(:message, attachment: true, attachments: build_list(:attachment, 1)))

            # NOTE: NO query param is_oh_triage_group - it's only inside the JSON string
            post '/mobile/v0/messaging/health/messages',
                 headers: sis_headers,
                 params: { message: stringified_message, uploads: }

            expect(response).to be_successful
          end

          it 'correctly detects is_oh_triage_group when inside stringified JSON on reply with attachments' do
            message_with_oh_flag = message_params.slice(:subject, :category, :recipient_id, :body)
                                                 .merge(is_oh_triage_group: true)
            stringified_message = message_with_oh_flag.to_json

            expect_any_instance_of(Mobile::V0::Messaging::Client)
              .to receive(:post_create_message_reply_with_attachment)
              .with(kind_of(String), kind_of(Hash), is_oh: true)
              .and_return(build(:message, attachment: true, attachments: build_list(:attachment, 1)))

            post '/mobile/v0/messaging/health/messages/674838/reply',
                 headers: sis_headers,
                 params: { message: stringified_message, uploads: }

            expect(response).to be_successful
          end

          it 'extends timeout when is_oh_triage_group is inside stringified JSON on create' do
            message_with_oh_flag = message_params.slice(:subject, :category, :recipient_id, :body)
                                                 .merge(is_oh_triage_group: true)
            stringified_message = message_with_oh_flag.to_json

            expect_any_instance_of(Mobile::V0::Messaging::Client)
              .to receive(:post_create_message_with_attachment)
              .with(kind_of(Hash), is_oh: true)
              .and_return(build(:message, attachment: true, attachments: build_list(:attachment, 1)))

            post '/mobile/v0/messaging/health/messages',
                 headers: sis_headers,
                 params: { message: stringified_message, uploads: }

            expect(response).to be_successful
            expect(request.env['rack-timeout.timeout']).to eq(Settings.mhv.sm.timeout)
          end

          it 'does not trigger polling when is_oh_triage_group is false inside stringified JSON' do
            message_with_oh_flag = message_params.slice(:subject, :category, :recipient_id, :body)
                                                 .merge(is_oh_triage_group: false)
            stringified_message = message_with_oh_flag.to_json

            # Should NOT receive is_oh: true
            expect_any_instance_of(Mobile::V0::Messaging::Client)
              .to receive(:post_create_message_with_attachment)
              .with(kind_of(Hash), is_oh: false)
              .and_return(build(:message, attachment: true, attachments: build_list(:attachment, 1)))

            post '/mobile/v0/messaging/health/messages',
                 headers: sis_headers,
                 params: { message: stringified_message, uploads: }

            expect(response).to be_successful
          end
        end

        context 'timeout extension for OH triage groups' do
          let(:message_params) { attributes_for(:message, subject: 'OH Group Subject', body: 'Body') }
          let(:params) { message_params.slice(:subject, :category, :recipient_id, :body) }

          it 'extends timeout when is_oh_triage_group=true on create' do
            VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments') do
              VCR.use_cassette('sm_client/messages/creates/status_sent') do
                post '/mobile/v0/messaging/health/messages?is_oh_triage_group=true',
                     headers: sis_headers,
                     params: { message: params }

                expect(response).to be_successful
                expect(request.env['rack-timeout.timeout']).to eq(Settings.mhv.sm.timeout)
              end
            end
          end

          it 'extends timeout when is_oh_triage_group=true on reply' do
            expect_any_instance_of(Mobile::V0::Messaging::Client).to receive(:poll_message_status)
              .and_return({ status: 'SENT' })
            VCR.use_cassette('sm_client/messages/creates/a_reply_without_attachments') do
              post '/mobile/v0/messaging/health/messages/674838/reply?is_oh_triage_group=true',
                   headers: sis_headers,
                   params: { message: params }

              expect(response).to be_successful
              expect(request.env['rack-timeout.timeout']).to eq(Settings.mhv.sm.timeout)
            end
          end

          it 'does not extend timeout when is_oh_triage_group=false on create' do
            VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments') do
              VCR.use_cassette('sm_client/messages/creates/status_sent') do
                post '/mobile/v0/messaging/health/messages?is_oh_triage_group=false',
                     headers: sis_headers,
                     params: { message: params }

                expect(response).to be_successful
                expect(request.env['rack-timeout.timeout']).not_to eq(Settings.mhv.sm.timeout)
              end
            end
          end

          it 'does not extend timeout when is_oh_triage_group param is absent on create' do
            VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments') do
              post '/mobile/v0/messaging/health/messages',
                   headers: sis_headers,
                   params: { message: params }

              expect(response).to be_successful
              expect(request.env['rack-timeout.timeout']).not_to eq(Settings.mhv.sm.timeout)
            end
          end

          it 'does not extend timeout when is_oh_triage_group=false on reply' do
            VCR.use_cassette('sm_client/messages/creates/a_reply_without_attachments') do
              post '/mobile/v0/messaging/health/messages/674838/reply?is_oh_triage_group=false',
                   headers: sis_headers,
                   params: { message: params }

              expect(response).to be_successful
              expect(request.env['rack-timeout.timeout']).not_to eq(Settings.mhv.sm.timeout)
            end
          end

          it 'does not extend timeout for non-create/reply actions like show' do
            VCR.use_cassette('sm_client/messages/gets_a_message_with_id') do
              VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_all_triage_team_recipients') do
                get "/mobile/v0/messaging/health/messages/#{message_id}?is_oh_triage_group=true",
                    headers: sis_headers

                expect(response).to be_successful
                expect(request.env['rack-timeout.timeout']).not_to eq(Settings.mhv.sm.timeout)
              end
            end
          end
        end
      end

      describe '#thread' do
        let(:thread_id) { 573_059 }

        it 'responds to GET #thread' do
          VCR.use_cassette('mobile/messages/v0_gets_a_message_thread') do
            get "/mobile/v0/messaging/health/messages/#{thread_id}/thread", headers: sis_headers
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response).to match_camelized_response_schema('messages_thread')
          expect(response.parsed_body.dig('meta', 'messageCounts', 'read')).to eq(1)
          expect(response.parsed_body.dig('meta', 'messageCounts', 'unread')).to eq(1)
        end
      end

      describe '#destroy' do
        let(:message_id) { 573_052 }

        it 'responds to DELETE' do
          VCR.use_cassette('sm_client/messages/deletes_the_message_with_id') do
            delete "/mobile/v0/messaging/health/messages/#{message_id}", headers: sis_headers
          end
          expect(response).to be_successful
          expect(response).to have_http_status(:no_content)
        end
      end

      describe '#move' do
        let(:message_id) { 573_052 }

        it 'responds to PATCH messages/move' do
          VCR.use_cassette('sm_client/messages/moves_a_message_with_id') do
            patch "/mobile/v0/messaging/health/messages/#{message_id}/move?folder_id=0", headers: sis_headers
          end

          expect(response).to be_successful
          expect(response).to have_http_status(:no_content)
        end

        context 'when message is not found' do
          it 'responds with expected error' do
            VCR.use_cassette('sm_client/messages/moves_a_message_with_id_error') do
              patch '/mobile/v0/messaging/health/messages/999999/move?folder_id=0', headers: sis_headers
            end
            expected_error = { 'errors' => [{ 'title' => 'Operation failed',
                                              'detail' => 'Message requested could not be found',
                                              'code' => 'SM904', 'source' => 'Severity[Error]:message.not.found;',
                                              'status' => '404' }] }
            expect(response).to have_http_status(:not_found)
            expect(response.parsed_body).to eq(expected_error)
          end
        end
      end

      describe 'message id validation' do
        it 'returns 400 for show with blank id' do
          get '/mobile/v0/messaging/health/messages/%20', headers: sis_headers

          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body['errors'].first['detail']).to include('id')
        end

        it 'returns 400 for thread with blank id' do
          get '/mobile/v0/messaging/health/messages/%20/thread', headers: sis_headers

          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body['errors'].first['detail']).to include('id')
        end

        it 'returns 400 for move with blank id' do
          patch '/mobile/v0/messaging/health/messages/%20/move?folder_id=0', headers: sis_headers

          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body['errors'].first['detail']).to include('id')
        end

        it 'returns 400 for destroy with blank id' do
          delete '/mobile/v0/messaging/health/messages/%20', headers: sis_headers

          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body['errors'].first['detail']).to include('id')
        end

        it 'returns 400 for reply with blank id' do
          post '/mobile/v0/messaging/health/messages/%20/reply',
               headers: sis_headers,
               params: { message: { category: 'OTHER', body: 'Test', recipient_id: '1', subject: 'Test' } }

          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body['errors'].first['detail']).to include('id')
        end
      end
    end
  end
end
