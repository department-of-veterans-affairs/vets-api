# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Messages Integration', type: :request do
  let(:user_id) { ENV['MHV_SM_USER_ID'] }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_302 }

  describe '#index' do
    it 'responds with all messages in a folder when no pagination is given' do
      VCR.use_cassette("sm/messages/#{user_id}/index") do
        get "/v0/messaging/health/folders/#{inbox_id}/messages"
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('messages')
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

  describe '#create' do
    let(:message_attributes) { attributes_for(:message).slice(:subject, :category, :recipient_id, :body) }
    let(:params) { { message: message_attributes } }

    it 'responds to POST #create' do
      VCR.use_cassette("sm/messages/#{user_id}/create") do
        post '/v0/messaging/health/messages', params
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('message')
    end
  end

  # TODO: complete draft deletion once clarification received on deleting draft messages
  # describe '#destroy' do
  #   let(:msg) { build :message }
  #
  #   before(:each) do
  #     VCR.use_cassette("sm/messages/#{user_id}/destroy") do
  #       post '/v0/messaging/health/messages', subject: msg.subject, category: msg.category,
  #                                             recipient_id: msg.recipient_id, body: msg.body
  #
  #       message_id = JSON.parse(response.body)['data']['attributes']['message_id']
  #       delete "/v0/messaging/health/messages/#{message_id}"
  #     end
  #   end
  #
  #   it 'responds to DELETE #destroy' do
  #   end
  # end

  # describe '#draft' do
  #   let(:msg) { build :message }
  #
  #   before(:each) do
  #     VCR.use_cassette("sm/messages/#{user_id}/draft_create") do
  #       post '/v0/messaging/health/messages/draft', subject: msg.subject, category: msg.category,
  #                                                   recipient_id: msg.recipient_id, body: msg.body
  #     end
  #   end
  #
  #   it 'responds to POST #draft' do
  #     expect(response).to be_success
  #     expect(response.body).to be_a(String)
  #     expect(response).to match_response_schema('message')
  #   end
  #
  #   it 'responds to PUT #draft' do
  #     org = JSON.parse(response.body)['data']['attributes']
  #     body = org['body'] + '. This is the added bit!'
  #     message_id = org['message_id']
  #
  #     VCR.use_cassette("sm/messages/#{user_id}/draft_update") do
  #       put "/v0/messaging/health/messages/#{message_id}/draft", subject: msg.subject, category: msg.category,
  #                                                                body: body, recipient_id: msg.recipient_id
  #     end
  #
  #     expect(response).to be_success
  #     expect(response.body).to be_a(String)
  #     expect(response).to match_response_schema('message')
  #     expect(JSON.parse(response.body)['data']['attributes']['body']).to eq(body)
  #     expect(JSON.parse(response.body)['data']['attributes']['message_id']).to eq(message_id)
  #   end
  # end

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
    let(:message_id) { 573_034 }

    context 'without folder_id' do
      it 'raises an error' do
        patch "/v0/messaging/health/messages/#{message_id}/move"
        binding.pry
      end
    end

    it 'responds to PATCH messages/move' do
      VCR.use_cassette("sm/messages/#{user_id}/move") do
        patch "/v0/messaging/health/messages/#{message_id}/move?folder_id=123"
      end

      binding.pry

      expect(response).to be_success
      expect(response.body).to be_a(String)
    end
  end
end
