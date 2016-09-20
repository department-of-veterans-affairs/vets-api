# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Messages Integration', type: :request do
  let(:user_id) { ENV['MHV_SM_USER_ID'] }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_302 }

  describe '#index' do
    before(:each) do
      VCR.use_cassette("sm/messages/#{user_id}/index") do
        get "/v0/messaging/health/folders/#{inbox_id}/messages"
      end
    end

    it 'responds with all messages in a folder when no pagination is given' do
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('messages')
    end

    it 'responds to GET #index with pagination parameters' do
      target_msg = JSON.parse(response.body)['data'][1]

      VCR.use_cassette("sm/messages/#{user_id}/index_pagination") do
        get "/v0/messaging/health/folders/#{inbox_id}/messages", page: 2, per_page: 1

        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('messages')

        msg = JSON.parse(response.body)['data'][0]
        expect(msg['id']).to eq(target_msg['id'])
      end
    end

    it 'can concatenate multiple MHV calls for GET all messages' do
      target_msgs = JSON.parse(response.body)['data']

      VCR.use_cassette("sm/messages/#{user_id}/index_concatenation") do
        # Forcing smaller per_page to test concatenation
        get "/v0/messaging/health/folders/#{inbox_id}/messages", per_page: 1, all: true

        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('messages')

        msgs = JSON.parse(response.body)['data']
        expect(target_msgs.length).to eq(msgs.length)
      end
    end
  end

  describe '#show' do
    context 'with valid id' do
      before(:each) do
        VCR.use_cassette("sm/messages/#{user_id}/show") do
          get "/v0/messaging/health/messages/#{message_id}"
        end
      end

      it 'responds to GET #show' do
        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('message')
      end
    end
  end

  describe '#create' do
    let(:msg) { build :message }

    before(:each) do
      VCR.use_cassette("sm/messages/#{user_id}/create") do
        post '/v0/messaging/health/messages', subject: msg.subject, category: msg.category,
                                              recipient_id: msg.recipient_id, body: msg.body
      end
    end

    it 'responds to POST #create' do
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
    before(:each) do
      VCR.use_cassette("sm/messages/#{user_id}/thread") do
        get "/v0/messaging/health/messages/#{thread_id}/thread"
      end
    end

    it 'responds to GET #thread' do
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('messages')
    end
  end

  describe 'when getting categories' do
    before(:each) do
      VCR.use_cassette("sm/messages/#{user_id}/category") do
        get '/v0/messaging/health/messages/categories'
      end
    end

    it 'responds to GET messages/categories' do
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('category')
    end
  end
end
