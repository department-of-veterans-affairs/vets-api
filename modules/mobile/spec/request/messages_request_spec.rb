# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/mobile_sm_client_helper'

RSpec.describe 'Mobile Messages Integration', type: :request do
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
      get '/mobile/v0/messaging/health/messages/categories', headers: iam_headers
      expect(response).not_to be_successful
      expect(response.status).to eq(403)
    end
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }

    it 'is not authorized' do
      get '/mobile/v0/messaging/health/messages/categories', headers: iam_headers
      expect(response).not_to be_successful
      expect(response.status).to eq(403)
    end
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

    it 'responds to GET messages/categories' do
      VCR.use_cassette('sm_client/messages/gets_message_categories') do
        get '/mobile/v0/messaging/health/messages/categories', headers: iam_headers
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('category')
    end

    it 'responds to GET #show' do
      VCR.use_cassette('sm_client/messages/gets_a_message_with_id') do
        get "/mobile/v0/messaging/health/messages/#{message_id}", headers: iam_headers
      end

      expect(response).to be_successful
      expect(response.body).to be_a(String)
      expect(response).to match_camelized_response_schema('message')
    end

    it 'generates mobile-specific metadata links' do
      VCR.use_cassette('sm_client/messages/gets_a_message_with_id') do
        get "/mobile/v0/messaging/health/messages/#{message_id}", headers: iam_headers
      end

      result = JSON.parse(response.body)
      expect(result['data']['links']['self']).to match(%r{/mobile/v0})
    end

    it 'returns message signature preferences' do
      VCR.use_cassette('sm_client/messages/gets_message_signature') do
        get '/mobile/v0/messaging/health/messages/signature', headers: iam_headers
      end

      result = JSON.parse(response.body)
      expect(result['data']['attributes']['signatureName']).to eq('test-api Name')
      expect(result['data']['attributes']['includeSignature']).to eq(true)
      expect(result['data']['attributes']['signatureTitle']).to eq('test-api title')
    end

    context 'when signature prefs are empty' do
      it 'returns empty message signature preferences' do
        VCR.use_cassette('sm_client/messages/gets_empty_message_signature') do
          get '/mobile/v0/messaging/health/messages/signature', headers: iam_headers
        end

        result = JSON.parse(response.body)
        expect(result['data']['attributes']['signatureName']).to eq(nil)
        expect(result['data']['attributes']['includeSignature']).to eq(false)
        expect(result['data']['attributes']['signatureTitle']).to eq(nil)
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
            post '/mobile/v0/messaging/health/messages', headers: iam_headers, params: { message: params }
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
          expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
          expect(response).to match_camelized_response_schema('message')
        end

        it 'with attachments' do
          VCR.use_cassette('sm_client/messages/creates/a_new_message_with_4_attachments') do
            post '/mobile/v0/messaging/health/messages', headers: iam_headers, params: params_with_attachments
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
            post "/mobile/v0/messaging/health/messages/#{reply_message_id}/reply",
                 headers: iam_headers, params: { message: params }
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
                 headers: iam_headers, params: params_with_attachments
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
        VCR.use_cassette('sm_client/messages/gets_a_message_thread') do
          get "/mobile/v0/messaging/health/messages/#{thread_id}/thread", headers: iam_headers
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
          delete "/mobile/v0/messaging/health/messages/#{message_id}", headers: iam_headers
        end

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
      end
    end

    describe '#move' do
      let(:message_id) { 573_052 }

      it 'responds to PATCH messages/move' do
        VCR.use_cassette('sm_client/messages/moves_a_message_with_id') do
          patch "/mobile/v0/messaging/health/messages/#{message_id}/move?folder_id=0", headers: iam_headers
        end

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
