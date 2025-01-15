# frozen_string_literal: true

require_relative '../../../../../support/helpers/rails_helper'

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

      it 'responds to GET #show' do
        VCR.use_cassette('mobile/messages/gets_a_message_with_id_and_attachment') do
          VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_triage_team_recipients') do
            get "/mobile/v0/messaging/health/messages/#{message_id}", headers: sis_headers
          end
        end
        expect(response).to be_successful
        expect(response.body).to be_a(String)
        response_hash = JSON.parse(response.body)
        response_hash.delete('meta')
        response.body = response_hash.to_json
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

      it 'generates mobile-specific metadata links' do
        VCR.use_cassette('sm_client/messages/gets_a_message_with_id') do
          VCR.use_cassette('sm_client/triage_teams/gets_a_collection_of_triage_team_recipients') do
            get "/mobile/v0/messaging/health/messages/#{message_id}", headers: sis_headers
          end
        end

        result = JSON.parse(response.body)
        expect(result['data']['links']['self']).to match(%r{/mobile/v0})
        expect(result['meta']['userInTriageTeam?']).to be(false)
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
        let(:params_with_attachments) { { message: params }.merge(uploads:) }

        context 'message' do
          it 'without attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments') do
              post '/mobile/v0/messaging/health/messages', headers: sis_headers, params: { message: params }
            end

            expect(response).to be_successful
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
            expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
            expect(response).to match_camelized_response_schema('message')
            included = response.parsed_body.dig('included', 0)
            expect(included).to be_nil
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
        end

        context 'reply' do
          let(:reply_message_id) { 674_838 }

          it 'without attachments' do
            VCR.use_cassette('sm_client/messages/creates/a_reply_without_attachments') do
              post "/mobile/v0/messaging/health/messages/#{reply_message_id}/reply",
                   headers: sis_headers, params: { message: params }
            end

            expect(response).to be_successful
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
            expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
            expect(response).to match_camelized_response_schema('message')
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
    end
  end
end
