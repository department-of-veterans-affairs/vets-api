# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

RSpec.describe 'Messages Integration', type: :request do
  include SM::ClientHelpers

  let(:current_user) { build(:mhv_user) }
  let(:user_id) { ENV['MHV_SM_USER_ID'] }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_059 }

  before(:each) do
    allow(SM::Client).to receive(:new).and_return(authenticated_client)
    use_authenticated_current_user(current_user: current_user)
  end

  it 'responds to GET #show' do
    VCR.use_cassette('sm_client/messages/gets_a_message_with_id') do
      get "/v0/messaging/health/messages/#{message_id}"
    end

    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('message')
  end

  describe 'POST create' do
    let(:attachment_type) { 'image/jpg' }
    let(:uploads) do
      [
        Rack::Test::UploadedFile.new('spec/support/fixtures/sm_file1.jpg', attachment_type),
        Rack::Test::UploadedFile.new('spec/support/fixtures/sm_file2.jpg', attachment_type),
        Rack::Test::UploadedFile.new('spec/support/fixtures/sm_file3.jpg', attachment_type),
        Rack::Test::UploadedFile.new('spec/support/fixtures/sm_file4.jpg', attachment_type)
      ]
    end
    let(:message_params) { attributes_for(:message, subject: 'CI Run', body: 'Continuous Integration') }
    let(:params) { message_params.slice(:subject, :category, :recipient_id, :body) }
    let(:params_with_attachments) { { message: params }.merge(uploads: uploads) }

    context 'message' do
      it 'without attachments' do
        VCR.use_cassette('sm_client/messages/creates/a_new_message_without_attachments') do
          post '/v0/messaging/health/messages', message: params
        end

        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
        expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
        expect(response).to match_response_schema('message')
      end

      it 'with attachments' do
        VCR.use_cassette('sm_client/messages/creates/a_new_message_with_4_attachments') do
          post '/v0/messaging/health/messages', params_with_attachments
        end

        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
        expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
        expect(response).to match_response_schema('message_with_attachment')
      end
    end

    context 'reply' do
      let(:reply_message_id) { 655_570 }

      it 'without attachments' do
        VCR.use_cassette('sm_client/messages/creates/a_reply_without_attachments') do
          post "/v0/messaging/health/messages/#{reply_message_id}/reply", message: params
        end

        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
        expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
        expect(response).to match_response_schema('message')
      end

      it 'with attachments' do
        VCR.use_cassette('sm_client/messages/creates/a_reply_with_4_attachments') do
          post "/v0/messaging/health/messages/#{reply_message_id}/reply", params_with_attachments
        end

        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('CI Run')
        expect(JSON.parse(response.body)['data']['attributes']['body']).to eq('Continuous Integration')
        expect(response).to match_response_schema('message_with_attachment')
      end
    end
  end

  describe '#thread' do
    let(:thread_id) { 573_059 }

    it 'responds to GET #thread' do
      VCR.use_cassette('sm_client/messages/gets_a_message_thread') do
        get "/v0/messaging/health/messages/#{thread_id}/thread"
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('messages_thread')
    end
  end

  describe '#categories' do
    it 'responds to GET messages/categories' do
      VCR.use_cassette('sm_client/messages/gets_message_categories') do
        get '/v0/messaging/health/messages/categories'
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('category')
    end
  end

  describe '#destroy' do
    let(:message_id) { 573_052 }

    it 'responds to DELETE' do
      VCR.use_cassette('sm_client/messages/deletes_the_message_with_id') do
        delete "/v0/messaging/health/messages/#{message_id}"
      end

      expect(response).to be_success
      expect(response).to have_http_status(:no_content)
    end
  end

  describe '#move' do
    let(:message_id) { 573_052 }

    it 'responds to PATCH messages/move' do
      VCR.use_cassette('sm_client/messages/moves_a_message_with_id') do
        patch "/v0/messaging/health/messages/#{message_id}/move?folder_id=0"
      end

      expect(response).to be_success
      expect(response).to have_http_status(:no_content)
    end
  end

  context 'with an LOA1 user' do
    let(:current_user) { build(:loa1_user) }

    it 'gives me a 401' do
      get "/v0/messaging/health/messages/#{message_id}"

      expect(response).not_to be_success
      expect(response.status).to eq(403)
    end
  end
end
