# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'

RSpec.describe 'sm', type: :request do
  # When re-recording cassettes:
  # identify a message to move and delete and set it as the let values below
  # make sure to run rspec in default order (not rand),
  # or run each spec individually (move first)
  # bundle exec rspec --order default

  let(:move_message_id)     { 653030 }
  let(:destroy_message_id)  { 653030 }
  let(:existing_folder_id)  { 610965 }

  describe 'messages' do
    before(:each) do
      allow_any_instance_of(ApplicationController).to receive(:authenticate).and_return(true)
    end

    let(:user_id) { ENV['MHV_SM_USER_ID'] }
    let(:inbox_id) { 0 }
    let(:message_id) { 573_302 }
    let(:thread_id) { 573_059 }
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

    describe 'responds to GET #index' do
      it 'complete collection', :vcr do
        get "/v0/messaging/health/folders/#{inbox_id}/messages"

        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('messages')
      end

      it 'filtered for multiple attributes', :vcr do
        filter = 'filter[[subject][eq]]=something&filter[[sender_name][eq]]=someone'
        get "/v0/messaging/health/folders/#{inbox_id}/messages?#{filter}"
        expect(response).to be_success
      end

      it 'filtered for multiple predicates on single field', :vcr do
        filter = 'filter[[sent_date][lteq]]=2016-01-01&filter[[sent_date][gteq]]=2016-01-01'
        get "/v0/messaging/health/folders/#{inbox_id}/messages?#{filter}"
        expect(response).to be_success
      end
    end

    it 'responds to GET #show', :vcr do
      get "/v0/messaging/health/messages/#{message_id}"

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('message')
    end

    it 'responds to GET #thread', :vcr do
      get "/v0/messaging/health/messages/#{thread_id}/thread"

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('messages')
    end

    it 'responds to GET messages/categories', :vcr do
      get '/v0/messaging/health/messages/categories'

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('category')
    end

    describe 'non idempotent actions' do
      it 'responds to PATCH #move', :vcr do
        patch "/v0/messaging/health/messages/#{move_message_id}/move?folder_id=#{existing_folder_id}"
        binding.pry
        expect(response).to be_success
        expect(response).to have_http_status(:no_content)
      end

      it 'responds to DELETE', :vcr do
        delete "/v0/messaging/health/messages/#{destroy_message_id}"

        expect(response).to be_success
        expect(response).to have_http_status(:no_content)
      end

      describe 'responds to POST #create' do
        let(:message_attributes) { attributes_for(:message).slice(:subject, :category, :recipient_id, :body) }
        let(:params) { { message: message_attributes } }
        let(:params_with_attachments) do
          {
            message: message_attributes,
            uploads: uploads
          }
        end

        it 'having no attachments', :vcr do
          post '/v0/messaging/health/messages', params

          expect(response).to be_success
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('message')
        end

        it 'having 4 attachments', :vcr do
          post '/v0/messaging/health/messages', params_with_attachments

          expect(response).to be_success
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('message_with_attachment')
        end
      end

      describe 'responds to POST #reply' do
        let(:message_attributes) { attributes_for(:message).slice(:subject, :category, :recipient_id, :body) }
        let(:params) { { message: message_attributes } }
        let(:params_with_attachments) do
          {
            message: { body: reply_body },
            uploads: uploads
          }
        end
        let(:reply_message_id) { 610_114 }
        let(:reply_body) { 'This is a reply body' }

        it 'having no attachments', :vcr do
          post "/v0/messaging/health/messages/#{reply_message_id}/reply", params

          expect(response).to be_success
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('message')
        end

        it 'having 4 attachments', :vcr do
          post "/v0/messaging/health/messages/#{reply_message_id}/reply", params_with_attachments

          expect(response).to be_success
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('message_with_attachment')
        end
      end
    end
  end
end
