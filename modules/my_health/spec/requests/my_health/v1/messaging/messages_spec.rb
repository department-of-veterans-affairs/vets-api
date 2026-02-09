# frozen_string_literal: true

require 'rails_helper'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'
require 'unique_user_events'

RSpec.describe 'MyHealth::V1::Messaging::Messages', type: :request do
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
      get "/my_health/v1/messaging/messages/#{message_id}"
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

    it 'responds to GET messages/categories' do
      VCR.use_cassette('sm_client/messages/gets_message_categories') do
        get '/my_health/v1/messaging/messages/categories'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('my_health/messaging/v1/category')
    end

    it 'responds to GET messages/categories when camel-inflected' do
      VCR.use_cassette('sm_client/messages/gets_message_categories') do
        get '/my_health/v1/messaging/messages/categories', headers: inflection_header
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('my_health/messaging/v1/category')
    end

    it 'returns message signature preferences' do
      VCR.use_cassette('sm_client/messages/gets_message_signature') do
        get '/my_health/v1/messaging/messages/signature', headers: inflection_header
      end

      result = JSON.parse(response.body)
      expect(result['data']['includeSignature']).to be(true)
      expect(result['data']['signatureTitle']).to eq('test-api title')
      expect(result['data']['signatureName']).to eq('test-api Name')
    end

    it 'responds to GET #show' do
      VCR.use_cassette('sm_client/messages/gets_a_message_with_id') do
        get "/my_health/v1/messaging/messages/#{message_id}"
      end

      expected_body_content =
        "Einstein once said: “Profound quote contents here”. \n\n" \
        "That was supposed to show a regular quote but it didn’t display like it did in the compose form.\n\n" \
        "Let’s try out more symbols here:\n\n" \
        "Single quote: ‘ contents’\nQuestion mark: ?\nColon: :\nDash: -\nLess than: <\nGreat then: >\nEquals: =\n" \
        "Asterisk: *\nAnd symbol: &\nDollar symbol: $\nDivide symbol: %\nAt symbol: @\nParentheses: ( contents )\n" \
        "Brackets: [ contents ]\nCurly braces: { contents }\nSemicolon: ;\nSlash: /\nPlus: +\nUp symbol: ^\n" \
        "Pound key: #\nExclamation: !"

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      # It should decode html entities
      expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('Quote test: “test”')
      expect(JSON.parse(response.body)['data']['attributes']['body']).to eq(expected_body_content)
      expect(response).to match_response_schema('my_health/messaging/v1/message')
    end

    it 'responds to GET #show when camel-inflected' do
      VCR.use_cassette('sm_client/messages/gets_a_message_with_id') do
        get "/my_health/v1/messaging/messages/#{message_id}", headers: inflection_header
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('my_health/messaging/v1/message')
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
      let(:params_with_attachments) { { message: params, uploads: } }

      context 'message' do
        it 'without attachments' do
          allow(UniqueUserEvents).to receive(:log_event)

          VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments') do
            post '/my_health/v1/messaging/messages', params: { message: params_with_station }
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_response_schema('my_health/messaging/v1/message')

          # Verify event logging was called with facility ID from station_number param
          expect(UniqueUserEvents).to have_received(:log_event).with(
            user: anything,
            event_name: UniqueUserEvents::EventRegistry::SECURE_MESSAGING_MESSAGE_SENT,
            event_facility_ids: ['979']
          )
        end

        it 'without attachments when camel-inflected' do
          VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments') do
            post '/my_health/v1/messaging/messages', params: { message: params }, headers: inflection_header
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_camelized_response_schema('my_health/messaging/v1/message')
        end

        it 'without station_number omits facility tracking' do
          allow(UniqueUserEvents).to receive(:log_event)

          VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments') do
            post '/my_health/v1/messaging/messages', params: { message: params }
          end

          expect(response).to be_successful

          # Verify event logging was called with empty facility IDs when station_number not provided
          expect(UniqueUserEvents).to have_received(:log_event).with(
            user: anything,
            event_name: UniqueUserEvents::EventRegistry::SECURE_MESSAGING_MESSAGE_SENT,
            event_facility_ids: []
          )
        end

        it 'with attachments' do
          VCR.use_cassette('sm_client/messages/creates/a_new_message_with_4_attachments') do
            post '/my_health/v1/messaging/messages', params: params_with_attachments
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_response_schema('my_health/messaging/v1/message_with_attachment')
        end

        it 'with attachments and is_oh_triage_group param' do
          expect_any_instance_of(SM::Client).to receive(:poll_message_status).and_return({ status: 'SENT' })
          VCR.use_cassette('sm_client/messages/creates/a_new_message_with_4_attachments') do
            post '/my_health/v1/messaging/messages?is_oh_triage_group=true', params: params_with_attachments
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_response_schema('my_health/messaging/v1/message_with_attachment')
        end

        it 'with attachments and is_oh_triage_group param false' do
          expect_any_instance_of(SM::Client).not_to receive(:poll_message_status)
          VCR.use_cassette('sm_client/messages/creates/a_new_message_with_4_attachments') do
            post '/my_health/v1/messaging/messages?is_oh_triage_group=false', params: params_with_attachments
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_response_schema('my_health/messaging/v1/message_with_attachment')
        end

        it 'with attachments when camel-inflected' do
          VCR.use_cassette('sm_client/messages/creates/a_new_message_with_4_attachments') do
            post '/my_health/v1/messaging/messages', params: params_with_attachments, headers: inflection_header
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_camelized_response_schema('my_health/messaging/v1/message_with_attachment')
        end
      end

      context 'reply' do
        let(:reply_message_id) { 674_838 }

        it 'without attachments' do
          allow(UniqueUserEvents).to receive(:log_event)

          VCR.use_cassette('sm_client/messages/creates/a_reply_without_attachments') do
            post "/my_health/v1/messaging/messages/#{reply_message_id}/reply",
                 params: { message: params_with_station }
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_response_schema('my_health/messaging/v1/message')

          # Verify event logging was called with facility ID from station_number param
          expect(UniqueUserEvents).to have_received(:log_event).with(
            user: anything,
            event_name: UniqueUserEvents::EventRegistry::SECURE_MESSAGING_MESSAGE_SENT,
            event_facility_ids: ['979']
          )
        end

        it 'without attachments when camel-inflected' do
          VCR.use_cassette('sm_client/messages/creates/a_reply_without_attachments') do
            post "/my_health/v1/messaging/messages/#{reply_message_id}/reply",
                 params: { message: params },
                 headers: inflection_header
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_camelized_response_schema('my_health/messaging/v1/message')
        end

        it 'with attachments' do
          VCR.use_cassette('sm_client/messages/creates/a_reply_with_4_attachments') do
            post "/my_health/v1/messaging/messages/#{reply_message_id}/reply", params: params_with_attachments
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_response_schema('my_health/messaging/v1/message_with_attachment')
        end

        it 'with attachments and is_oh_triage_group param' do
          expect_any_instance_of(SM::Client).to receive(:poll_message_status).and_return({ status: 'SENT' })
          VCR.use_cassette('sm_client/messages/creates/a_reply_with_4_attachments') do
            post "/my_health/v1/messaging/messages/#{reply_message_id}/reply?is_oh_triage_group=true",
                 params: params_with_attachments
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_response_schema('my_health/messaging/v1/message_with_attachment')
        end

        it 'with attachments and is_oh_triage_group param false' do
          expect_any_instance_of(SM::Client).not_to receive(:poll_message_status)
          VCR.use_cassette('sm_client/messages/creates/a_reply_with_4_attachments') do
            post "/my_health/v1/messaging/messages/#{reply_message_id}/reply?is_oh_triage_group=false",
                 params: params_with_attachments
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_response_schema('my_health/messaging/v1/message_with_attachment')
        end

        it 'with attachments when camel-inflected' do
          VCR.use_cassette('sm_client/messages/creates/a_reply_with_4_attachments') do
            post "/my_health/v1/messaging/messages/#{reply_message_id}/reply",
                 params: params_with_attachments,
                 headers: inflection_header
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_camelized_response_schema('my_health/messaging/v1/message_with_attachment')
        end
      end

      context 'timeout extension for OH triage groups' do
        let(:reply_message_id) { 674_838 }

        it 'extends timeout when is_oh_triage_group=true on create' do
          VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments') do
            VCR.use_cassette('sm_client/messages/creates/status_sent') do
              post '/my_health/v1/messaging/messages?is_oh_triage_group=true',
                   params: { message: params }

              expect(response).to be_successful
              expect(request.env['rack-timeout.timeout']).to eq(Settings.mhv.sm.timeout)
            end
          end
        end

        it 'extends timeout when is_oh_triage_group=true on reply' do
          expect_any_instance_of(SM::Client).to receive(:poll_message_status).and_return({ status: 'SENT' })
          VCR.use_cassette('sm_client/messages/creates/a_reply_without_attachments') do
            post "/my_health/v1/messaging/messages/#{reply_message_id}/reply?is_oh_triage_group=true",
                 params: { message: params }

            expect(response).to be_successful
            expect(request.env['rack-timeout.timeout']).to eq(Settings.mhv.sm.timeout)
          end
        end

        it 'does not extend timeout when is_oh_triage_group=false on create' do
          VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments') do
            post '/my_health/v1/messaging/messages?is_oh_triage_group=false',
                 params: { message: params }

            expect(response).to be_successful
            expect(request.env['rack-timeout.timeout']).not_to eq(Settings.mhv.sm.timeout)
          end
        end

        it 'does not extend timeout when is_oh_triage_group param is absent on create' do
          VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments') do
            post '/my_health/v1/messaging/messages',
                 params: { message: params }

            expect(response).to be_successful
            expect(request.env['rack-timeout.timeout']).not_to eq(Settings.mhv.sm.timeout)
          end
        end

        it 'does not extend timeout when is_oh_triage_group=false on reply' do
          VCR.use_cassette('sm_client/messages/creates/a_reply_without_attachments') do
            post "/my_health/v1/messaging/messages/#{reply_message_id}/reply?is_oh_triage_group=false",
                 params: { message: params }

            expect(response).to be_successful
            expect(request.env['rack-timeout.timeout']).not_to eq(Settings.mhv.sm.timeout)
          end
        end

        it 'does not extend timeout for non-create/reply actions like show' do
          VCR.use_cassette('sm_client/messages/gets_a_message_with_id') do
            get "/my_health/v1/messaging/messages/#{message_id}?is_oh_triage_group=true"

            expect(response).to be_successful
            expect(request.env['rack-timeout.timeout']).not_to eq(Settings.mhv.sm.timeout)
          end
        end
      end
    end

    describe '#thread' do
      let(:thread_id) { 3_188_782 }

      it 'responds to GET #thread' do
        VCR.use_cassette('sm_client/messages/gets_a_message_thread_full') do
          get "/my_health/v1/messaging/messages/#{thread_id}/thread"
        end
        json_response = JSON.parse(response.body)
        data = json_response['data']
        expect(data).to be_an(Array)
        first_message = data.first['attributes']
        expect(first_message['message_id']).to eq(3_207_476)
        expect(first_message['thread_id']).to eq(3_188_781)
        expect(first_message['sender_id']).to eq(251_391)
        expect(first_message['sender_name']).to eq('MHVDAYMARK, MARK')
        expect(first_message['recipient_id']).to eq(3_188_767)
        expect(first_message['recipient_name']).to eq('TG API TESTING')
        expect(first_message['sent_date']).to be_nil
        expect(first_message['draft_date']).to eq('2023-12-19T17:21:47+00:00')
        expect(first_message['triage_group_name']).to eq('TG API TESTING')
        expect(first_message['has_attachments']).to be(false)
        expect(first_message['subject']).to eq('Test Inquiry')
        expect(first_message['category']).to eq('TEST_RESULTS')
        expect(first_message['folder_id']).to eq(-2)
        expect(first_message['message_body']).to eq('TEST0101010101')
        expect(first_message['proxy_sender_name']).to be_nil
        expect(first_message['read_receipt']).to be_nil
        expect(response).to be_successful
      end

      it 'responds to GET #thread with full_body query param' do
        VCR.use_cassette('sm_client/messages/gets_a_message_thread_full_body') do
          get "/my_health/v1/messaging/messages/#{thread_id}/thread?full_body=true"
        end

        json_response = JSON.parse(response.body)
        data = json_response['data']

        expect(data).to be_an(Array)

        first_message = data.first['attributes']
        expect(first_message['message_id']).to eq(3_207_476)
        expect(first_message['attachments']).to be_empty

        second_message = data[1]['attributes']
        expect(second_message['message_id']).to eq(3_204_755)

        attachments = second_message['attachments']
        expect(attachments.length).to eq(2)

        first_attachment = attachments.first
        expect(first_attachment['id']).to eq(3_204_753)
        expect(first_attachment['name']).to eq('almost4mbfile.pdf')
        expect(first_attachment['attachment_size']).to eq(3_976_877)
        expect(first_attachment['message_id']).to eq(3_204_755)

        third_message = data[2]['attributes']
        expect(third_message['message_id']).to eq(3_203_739)
        expect(third_message['message_body'].length).to be > 200
      end

      it 'responds to GET #thread when camel-inflected' do
        VCR.use_cassette('sm_client/messages/gets_a_message_thread_full') do
          get "/my_health/v1/messaging/messages/#{thread_id}/thread", headers: { 'X-Key-Inflection': 'camel' }
        end

        json_response = JSON.parse(response.body)
        data = json_response['data']

        expect(response).to be_successful
        expect(data).to be_a(Array)
        first_message = data.first['attributes']
        expect(first_message['messageId']).to eq(3_207_476)
        expect(first_message['threadId']).to eq(3_188_781)
        expect(first_message['senderId']).to eq(251_391)
      end

      it 'responds to GET #thread with replyDisabled' do
        VCR.use_cassette('sm_client/messages/gets_a_message_thread_full') do
          get "/my_health/v1/messaging/messages/#{thread_id}/thread"
        end
        json_response = JSON.parse(response.body)
        data = json_response['data']
        expect(data).to be_an(Array)
        expect(data[0]['attributes']['reply_disabled']).to be(true)
        expect(data[1]['attributes']['reply_disabled']).to be(false)
        expect(data[2]['attributes']['reply_disabled']).to be(false)
      end
    end

    describe '#destroy' do
      let(:message_id) { 573_052 }

      it 'responds to DELETE' do
        VCR.use_cassette('sm_client/messages/deletes_the_message_with_id') do
          delete "/my_health/v1/messaging/messages/#{message_id}"
        end

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
      end
    end

    describe '#move' do
      let(:message_id) { 573_052 }

      it 'responds to PATCH messages/move' do
        VCR.use_cassette('sm_client/messages/moves_a_message_with_id') do
          patch "/my_health/v1/messaging/messages/#{message_id}/move?folder_id=0"
        end

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
      end
    end

    describe 'POST create with large attachments feature flag' do
      let(:attachment_type) { 'image/jpg' }
      let(:uploads) do
        [
          Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1.jpg', attachment_type),
          Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file2.jpg', attachment_type)
        ]
      end
      let(:message_params) do
        attributes_for(:message, subject: 'CI Run', body: 'Continuous Integration')
      end
      let(:params) { message_params.slice(:subject, :category, :body, :recipient_id) }
      let(:params_with_attachments) { { message: params, uploads: } }

      before do
        allow_any_instance_of(ActionDispatch::Http::UploadedFile).to receive(:size).and_return(7.megabytes)
        allow_any_instance_of(SM::Client).to receive(:post_create_message_with_lg_attachments).and_call_original
        allow_any_instance_of(SM::Client).to receive(:post_create_message_with_attachment).and_call_original
      end

      context 'mhv_secure_messaging_cerner_pilot flag enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_cerner_pilot, anything).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_large_attachments).and_return(false)
        end

        it 'without is_oh_triage_group param' do
          # when is_oh_triage_group not sent, so the attachments exceeding 6 MB should not be allowed
          # and the ValidationException is expected to be thrown

          post '/my_health/v1/messaging/messages', params: params_with_attachments

          # Check for validation error response instead of exception
          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
          expect(json_response['errors'].first['detail']).to include('exceeds file size limit')
        end

        it 'without is_oh_triage_group param and legacy attachment requirements' do
          allow_any_instance_of(ActionDispatch::Http::UploadedFile).to receive(:size).and_return(5.megabytes)
          VCR.use_cassette('sm_client/messages/creates/a_new_message_with_4_attachments') do
            post '/my_health/v1/messaging/messages', params: params_with_attachments
          end

          expect(response).to be_successful
        end

        it 'with is_oh_triage_group param' do
          expect_any_instance_of(SM::Client).to receive(:poll_message_status).and_return({ status: 'SENT' })
          VCR.use_cassette('sm_client/messages/creates/aws_s3_attachment_upload_pre_signed_url') do
            post '/my_health/v1/messaging/messages?is_oh_triage_group=true', params: params_with_attachments
          end

          expect(response).to be_successful
          json_response = JSON.parse(response.body)
          expect(json_response['data']['id']).to be_present
        end
      end

      context 'mhv_secure_messaging_large_attachments flag enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_cerner_pilot, anything).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_large_attachments).and_return(true)
        end

        it 'with is_oh_triage_group param' do
          expect_any_instance_of(SM::Client).to receive(:poll_message_status).and_return({ status: 'SENT' })
          VCR.use_cassette('sm_client/messages/creates/aws_s3_attachment_upload_pre_signed_url') do
            post '/my_health/v1/messaging/messages?is_oh_triage_group=true', params: params_with_attachments
          end

          expect(response).to be_successful
          json_response = JSON.parse(response.body)
          expect(json_response['data']['id']).to be_present
        end

        it 'without is_oh_triage_group param' do
          expect_any_instance_of(SM::Client).not_to receive(:poll_message_status)
          VCR.use_cassette('sm_client/messages/creates/aws_s3_attachment_upload_pre_signed_url') do
            post '/my_health/v1/messaging/messages', params: params_with_attachments
          end

          expect(response).to be_successful
          json_response = JSON.parse(response.body)
          expect(json_response['data']['id']).to be_present
        end
      end
    end

    describe 'POST reply with large attachments feature flag' do
      let(:reply_message_id) { 5_993_651 }
      let(:attachment_type) { 'image/jpg' }
      let(:uploads) do
        [
          Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1.jpg', attachment_type)
        ]
      end
      let(:message_params) do
        attributes_for(:message, subject: 'CI Run', body: 'Continuous Integration')
      end
      let(:params) { message_params.slice(:subject, :category, :body, :recipient_id) }
      let(:params_with_attachments) { { message: params, uploads: } }

      before do
        allow_any_instance_of(ActionDispatch::Http::UploadedFile).to receive(:size).and_return(7.megabytes)
        allow_any_instance_of(SM::Client).to receive(:post_create_message_with_lg_attachments).and_call_original
        allow_any_instance_of(SM::Client).to receive(:post_create_message_with_attachment).and_call_original
      end

      context 'mhv_secure_messaging_cerner_pilot flag enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_cerner_pilot, anything).and_return(true)
          allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_large_attachments).and_return(false)
        end

        it 'without is_oh_triage_group param' do
          # when is_oh_triage_group not sent, so the attachments exceeding 6 MB should not be allowed
          # and the ValidationException is expected to be thrown
          post "/my_health/v1/messaging/messages/#{reply_message_id}/reply", params: params_with_attachments

          # Check for validation error response instead of exception
          expect(response).to have_http_status(:unprocessable_entity)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
          expect(json_response['errors'].first['detail']).to include('exceeds file size limit')
        end

        it 'without is_oh_triage_group param and legacy attachment requirements' do
          allow_any_instance_of(ActionDispatch::Http::UploadedFile).to receive(:size).and_return(5.megabytes)

          VCR.use_cassette('sm_client/messages/creates/a_reply_with_4_attachments') do
            post '/my_health/v1/messaging/messages/674838/reply', params: params_with_attachments
          end
          expect(response).to be_successful
        end

        it 'with is_oh_triage_group param' do
          expect_any_instance_of(SM::Client).to receive(:poll_message_status).and_return({ status: 'SENT' })
          VCR.use_cassette('sm_client/messages/creates/aws_s3_attachment_upload_pre_signed_url_reply') do
            post "/my_health/v1/messaging/messages/#{reply_message_id}/reply?is_oh_triage_group=true",
                 params: params_with_attachments
          end

          expect(response).to be_successful
          json_response = JSON.parse(response.body)
          expect(json_response['data']['id']).to be_present
        end
      end

      context 'mhv_secure_messaging_large_attachments flag enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_cerner_pilot, anything).and_return(false)
          allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_large_attachments).and_return(true)
        end

        it 'with is_oh_triage_group param' do
          expect_any_instance_of(SM::Client).to receive(:poll_message_status).and_return({ status: 'SENT' })
          VCR.use_cassette('sm_client/messages/creates/aws_s3_attachment_upload_pre_signed_url_reply') do
            post "/my_health/v1/messaging/messages/#{reply_message_id}/reply?is_oh_triage_group=true",
                 params: params_with_attachments
          end

          expect(response).to be_successful
          json_response = JSON.parse(response.body)
          expect(json_response['data']['id']).to be_present
        end

        it 'without is_oh_triage_group param' do
          expect_any_instance_of(SM::Client).not_to receive(:poll_message_status)
          VCR.use_cassette('sm_client/messages/creates/aws_s3_attachment_upload_pre_signed_url_reply') do
            post "/my_health/v1/messaging/messages/#{reply_message_id}/reply",
                 params: params_with_attachments
          end

          expect(response).to be_successful
          json_response = JSON.parse(response.body)
          expect(json_response['data']['id']).to be_present
        end
      end
    end
  end

  context 'with authorized and requires_oh_messages flipper enabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_cerner_pilot, anything).and_return(true)
    end

    let(:thread_id) { 3_188_782 }

    it 'responds to GET #thread when requires_oh_messages flipper is provided' do
      VCR.use_cassette('sm_client/session_require_oh') do
        VCR.use_cassette('sm_client/messages/gets_a_message_thread_oh_messages') do
          get "/my_health/v1/messaging/messages/#{thread_id}/thread"
        end
      end
      expect(response).to be_successful

      json_response = JSON.parse(response.body)
      data = json_response['data']

      first_message = data.first['attributes']
      expect(first_message['is_oh_message']).to be(true)
    end
  end
end
