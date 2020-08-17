# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'Messages Integration', type: :request do
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

    before { get '/v0/messaging/health/messages/categories' }

    include_examples 'for user account level', message: 'You do not have access to messaging'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }

    before { get '/v0/messaging/health/messages/categories' }

    include_examples 'for user account level', message: 'You do not have access to messaging'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

    context 'not a va patient' do
      before { get '/v0/messaging/health/messages/categories' }

      let(:va_patient) { false }

      include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
    end

    it 'responds to GET messages/categories' do
      VCR.use_cassette('sm_client/messages/gets_message_categories') do
        get '/v0/messaging/health/messages/categories'
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('category')
    end

    it 'responds to GET messages/categories when camel-inflected' do
      VCR.use_cassette('sm_client/messages/gets_message_categories') do
        get '/v0/messaging/health/messages/categories', headers: inflection_header
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('category')
    end

    it 'responds to GET #show' do
      VCR.use_cassette('sm_client/messages/gets_a_message_with_id') do
        get "/v0/messaging/health/messages/#{message_id}"
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('message')
    end

    it 'responds to GET #show when camel-inflected' do
      VCR.use_cassette('sm_client/messages/gets_a_message_with_id') do
        get "/v0/messaging/health/messages/#{message_id}", headers: inflection_header
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('message')
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
      let(:params_with_attachments) { { message: params }.merge(uploads: uploads) }

      context 'message' do
        it 'without attachments' do
          VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments') do
            post '/v0/messaging/health/messages', params: { message: params }
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_response_schema('message')
        end

        it 'without attachments when camel-inflected' do
          VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments') do
            post '/v0/messaging/health/messages', params: { message: params }, headers: inflection_header
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_camelized_response_schema('message')
        end

        it 'with attachments' do
          VCR.use_cassette('sm_client/messages/creates/a_new_message_with_4_attachments') do
            post '/v0/messaging/health/messages', params: params_with_attachments
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_response_schema('message_with_attachment')
        end

        it 'with attachments when camel-inflected' do
          VCR.use_cassette('sm_client/messages/creates/a_new_message_with_4_attachments') do
            post '/v0/messaging/health/messages', params: params_with_attachments, headers: inflection_header
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_camelized_response_schema('message_with_attachment')
        end
      end

      context 'reply' do
        let(:reply_message_id) { 674_838 }

        it 'without attachments' do
          VCR.use_cassette('sm_client/messages/creates/a_reply_without_attachments') do
            post "/v0/messaging/health/messages/#{reply_message_id}/reply", params: { message: params }
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_response_schema('message')
        end

        it 'without attachments when camel-inflected' do
          VCR.use_cassette('sm_client/messages/creates/a_reply_without_attachments') do
            post "/v0/messaging/health/messages/#{reply_message_id}/reply",
                 params: { message: params },
                 headers: inflection_header
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_camelized_response_schema('message')
        end

        it 'with attachments' do
          VCR.use_cassette('sm_client/messages/creates/a_reply_with_4_attachments') do
            post "/v0/messaging/health/messages/#{reply_message_id}/reply", params: params_with_attachments
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_response_schema('message_with_attachment')
        end

        it 'with attachments when camel-inflected' do
          VCR.use_cassette('sm_client/messages/creates/a_reply_with_4_attachments') do
            post "/v0/messaging/health/messages/#{reply_message_id}/reply",
                 params: params_with_attachments,
                 headers: inflection_header
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_camelized_response_schema('message_with_attachment')
        end
      end
    end

    describe '#thread' do
      let(:thread_id) { 573_059 }

      it 'responds to GET #thread' do
        VCR.use_cassette('sm_client/messages/gets_a_message_thread') do
          get "/v0/messaging/health/messages/#{thread_id}/thread"
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('messages_thread')
      end

      it 'responds to GET #thread when camel-inflected' do
        VCR.use_cassette('sm_client/messages/gets_a_message_thread') do
          get "/v0/messaging/health/messages/#{thread_id}/thread", headers: inflection_header
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('messages_thread')
      end
    end

    describe '#destroy' do
      let(:message_id) { 573_052 }

      it 'responds to DELETE' do
        VCR.use_cassette('sm_client/messages/deletes_the_message_with_id') do
          delete "/v0/messaging/health/messages/#{message_id}"
        end

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
      end
    end

    describe '#move' do
      let(:message_id) { 573_052 }

      it 'responds to PATCH messages/move' do
        VCR.use_cassette('sm_client/messages/moves_a_message_with_id') do
          patch "/v0/messaging/health/messages/#{message_id}/move?folder_id=0"
        end

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
