# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

RSpec.describe 'Messages Integration', type: :request do
  include SM::ClientHelpers

  before(:each) do
    allow_any_instance_of(ApplicationController).to receive(:authenticate).and_return(true)
    expect(SM::Client).to receive(:new).once.and_return(authenticated_client)
  end

  let(:user_id) { ENV['MHV_SM_USER_ID'] }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_302 }
  let(:attachment_base_path) { 'spec/support/fixtures/' }
  let(:attachment_type) { 'image/jpg' }
  let(:uploads) do
    [
      Rack::Test::UploadedFile.new('spec/support/fixtures/sm_file1.jpg', attachment_type),
      Rack::Test::UploadedFile.new('spec/support/fixtures/sm_file2.jpg', attachment_type),
      Rack::Test::UploadedFile.new('spec/support/fixtures/sm_file3.jpg', attachment_type),
      Rack::Test::UploadedFile.new('spec/support/fixtures/sm_file4.jpg', attachment_type)
    ]
  end

  describe '#index' do
    it 'responds with all messages in a folder when no pagination is given' do
      VCR.use_cassette("sm/messages/#{user_id}/index") do
        get "/v0/messaging/health/folders/#{inbox_id}/messages"
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('messages')
    end

    context 'when verifying correct filters' do
      it 'accepts one attribute' do
        VCR.use_cassette("sm/messages/#{user_id}/index") do
          get "/v0/messaging/health/folders/#{inbox_id}/messages?filter[[subject][eq]]=something"
          expect(response).to be_success
        end
      end

      it 'accepts more than 1 attribute' do
        VCR.use_cassette("sm/messages/#{user_id}/index") do
          filter = 'filter[[subject][eq]]=something&filter[[sender_name][eq]]=someone'
          get "/v0/messaging/health/folders/#{inbox_id}/messages?#{filter}"
          expect(response).to be_success
        end
      end

      it 'accepts multiple predicates for a single attribute' do
        VCR.use_cassette("sm/messages/#{user_id}/index") do
          filter = 'filter[[sent_date][lteq]]=2016-01-01&filter[[sent_date][gteq]]=2016-01-01'
          get "/v0/messaging/health/folders/#{inbox_id}/messages?#{filter}"
          expect(response).to be_success
        end
      end
    end

    context 'when verifying incorrect filters' do
      it 'accepts only permitted attributes' do
        VCR.use_cassette("sm/messages/#{user_id}/index") do
          get "/v0/messaging/health/folders/#{inbox_id}/messages?filter[[blab][eq]]=1"
          error = JSON.parse(response.body)['errors'].first

          expect(response).not_to be_success
          expect(error['title']).to eq('Filter not allowed')
          expect(error['detail']).to eq('"blab" is not allowed for filtering')
        end
      end

      it 'accepts only permitted operations' do
        VCR.use_cassette("sm/messages/#{user_id}/index") do
          get "/v0/messaging/health/folders/#{inbox_id}/messages?filter[[sent_date][blah]]=1"

          error = JSON.parse(response.body)['errors'].first

          expect(response).not_to be_success
          expect(error['title']).to eq('Filter not allowed')
          expect(error['detail']).to eq('"blah for sent_date" is not allowed for filtering')
        end
      end

      it 'requires a convertible filter value' do
        VCR.use_cassette("sm/messages/#{user_id}/index") do
          get "/v0/messaging/health/folders/#{inbox_id}/messages?filter[[sent_date][eq]]=abcd"

          error = JSON.parse(response.body)['errors'].first

          expect(response).not_to be_success
          expect(error['title']).to eq('Invalid filters syntax')
          expect(error['detail']).to eq('The syntax for your filters is invalid')
        end
      end

      it 'requires a properly formed grammar' do
        VCR.use_cassette("sm/messages/#{user_id}/index") do
          get "/v0/messaging/health/folders/#{inbox_id}/messages?filter[[sent_date][]]=1"
          error = JSON.parse(response.body)['errors'].first

          expect(response).not_to be_success
          expect(error['title']).to eq('Invalid filters syntax')
        end
      end
    end
  end

  describe '#show' do
    context 'with valid id' do
      it 'responds to GET #show' do
        VCR.use_cassette("sm/messages/#{user_id}/show") do
          get "/v0/messaging/health/messages/#{message_id}"
        end

        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('message')
      end
    end
  end

  describe '#create without attachments' do
    let(:message_attributes) { attributes_for(:message).slice(:subject, :category, :recipient_id, :body) }
    let(:params) { { message: message_attributes } }

    context 'with valid attributes' do
      it 'responds to POST #create' do
        VCR.use_cassette("sm/messages/#{user_id}/create") do
          post '/v0/messaging/health/messages', params
        end

        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('message')
      end

      it 'subject defaults to general inquery' do
        VCR.use_cassette("sm/messages/#{user_id}/create_no_subject") do
          post '/v0/messaging/health/messages', message: message_attributes.slice(:recipient_id, :category, :body)
        end

        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('message')
        expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('General Inquiry')
      end
    end

    context 'with missing attributes' do
      it 'requires a recipient_id' do
        post '/v0/messaging/health/messages', message: message_attributes.slice(:subject, :category, :body)

        errors = JSON.parse(response.body)['errors'].first

        expect(response).to have_http_status(:unprocessable_entity)
        expect(errors['title']).to eq("Recipient can't be blank")
      end

      it 'requires a body' do
        post '/v0/messaging/health/messages', message: message_attributes.slice(:subject, :category, :recipient_id)

        errors = JSON.parse(response.body)['errors'].first

        expect(response).to have_http_status(:unprocessable_entity)
        expect(errors['title']).to eq("Body can't be blank")
      end

      it 'requires a category' do
        post '/v0/messaging/health/messages', message: message_attributes.slice(:subject, :body, :recipient_id)

        errors = JSON.parse(response.body)['errors'].first

        expect(response).to have_http_status(:unprocessable_entity)
        expect(errors['title']).to eq("Category can't be blank")
      end
    end
  end

  describe '#create with attachments' do
    let(:message_attributes) { attributes_for(:message).slice(:subject, :category, :recipient_id, :body) }

    context 'with valid attributes for 4 attachments' do
      let(:params) do
        {
          message: message_attributes,
          uploads: uploads
        }
      end

      it 'responds to POST #create' do
        VCR.use_cassette("sm/messages/#{user_id}/create_multipart") do
          post '/v0/messaging/health/messages', params
        end
        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('message_with_attachment')
      end
    end
  end

  describe '#reply' do
    let(:message_attributes) { attributes_for(:message).slice(:subject, :category, :recipient_id, :body) }
    let(:params) { { message: message_attributes } }

    let(:reply_message_id) { 610_114 }
    let(:reply_body) { 'This is a reply body' }

    context 'with valid attributes' do
      it 'responds to POST #reply' do
        VCR.use_cassette("sm/messages/#{user_id}/create_message_reply") do
          post "/v0/messaging/health/messages/#{reply_message_id}/reply", params
        end

        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('message')
      end
    end

    context 'with invalid attributes' do
      it 'requires a valid message to which it responds' do
        VCR.use_cassette("sm/messages/#{user_id}/create_reply_bad_id") do
          post '/v0/messaging/health/messages/-12345/reply', params
        end

        errors = JSON.parse(response.body)['errors'].first

        expect(response).to have_http_status(:bad_request)
        expect(errors['title']).to eq('Operation failed')
        expect(errors['detail']).to eq('Message service error')
        expect(errors['code']).to eq('900')
        expect(errors['status']).to eq('400')
      end

      it 'requires a body' do
        post "/v0/messaging/health/messages/#{reply_message_id}/reply",
             message: message_attributes.slice(:subject, :category, :recipient_id)

        errors = JSON.parse(response.body)['errors'].first

        expect(response).to have_http_status(:unprocessable_entity)
        expect(errors['title']).to eq("Body can't be blank")
      end
    end
  end

  describe '#reply with attachments' do
    let(:reply_message_id) { 610_114 }
    let(:reply_body) { 'This is a reply body' }

    context 'with valid attributes for 4 attachments' do
      let(:params) do
        {
          message: { body: reply_body },
          uploads: uploads
        }
      end

      it 'responds to POST #reply' do
        VCR.use_cassette("sm/messages/#{user_id}/create_reply_multipart") do
          post "/v0/messaging/health/messages/#{reply_message_id}/reply", params
        end
        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('message')
      end
    end
  end

  describe '#thread' do
    let(:thread_id) { 573_059 }

    it 'responds to GET #thread' do
      VCR.use_cassette("sm/messages/#{user_id}/thread") do
        get "/v0/messaging/health/messages/#{thread_id}/thread"
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('messages')
    end
  end

  describe 'when getting categories' do
    it 'responds to GET messages/categories' do
      VCR.use_cassette("sm/messages/#{user_id}/category") do
        get '/v0/messaging/health/messages/categories'
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('category')
    end
  end

  describe 'when moving messages between folders' do
    let(:message_id) { 573_052 }

    context 'without folder_id' do
      it 'returns errors json' do
        patch "/v0/messaging/health/messages/#{message_id}/move"
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('The required parameter "folder_id", is missing')
      end
    end

    it 'responds to PATCH messages/move' do
      VCR.use_cassette("sm/messages/#{user_id}/move") do
        patch "/v0/messaging/health/messages/#{message_id}/move?folder_id=610965"
      end

      expect(response).to be_success
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'when destroying a message' do
    let(:message_id) { 573_034 }

    it 'responds to DELETE' do
      VCR.use_cassette('sm/messages/10616687/delete') do
        delete "/v0/messaging/health/messages/#{message_id}"
      end

      expect(response).to be_success
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'when destroying a draft' do
    let(:message_id) { 623_373 }

    it 'responds to DELETE' do
      VCR.use_cassette('sm/messages/10616687/delete_draft') do
        delete "/v0/messaging/health/messages/#{message_id}"
      end

      expect(response).to be_success
      expect(response).to have_http_status(:no_content)
    end
  end
end
