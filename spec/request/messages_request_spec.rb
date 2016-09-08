# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Messages Integration', type: :request do
  let(:id) { ENV['MHV_SM_USER_ID'] }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_302 }

  describe '#index' do
    before(:each) do
      VCR.use_cassette("messages/#{id}/index") do
        get "/v0/messaging/health/folders/#{inbox_id}/messages", id: id
      end
    end

    it 'responds to GET #index' do
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('messages')
    end
  end

  describe '#show' do
    context 'with valid id' do
      before(:each) do
        VCR.use_cassette("messages/#{id}/show") do
          get "/v0/messaging/health/messages/#{message_id}", id: id
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
      VCR.use_cassette("messages/#{id}/create") do
        post '/v0/messaging/health/messages', id: id, subject: msg.subject, category: msg.category,
                                              recipient_id: msg.recipient_id, body: msg.body
      end
    end

    it 'responds to PUT #create' do
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('message')
    end
  end

  describe '#draft' do
    let(:msg) { build :message }

    before(:each) do
      VCR.use_cassette("messages/#{id}/draft_create") do
        post '/v0/messaging/health/messages/draft', id: id, subject: msg.subject, category: msg.category,
                                                    recipient_id: msg.recipient_id, body: msg.body
      end
    end

    it 'responds to POST #draft' do
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('message')
    end

    it 'responds to PUT #draft' do
      org = JSON.parse(response.body)['data']['attributes']
      body = org['body'] + '. This is the added bit!'
      message_id = org['message_id']

      VCR.use_cassette("messages/#{id}/draft_update") do
        put "/v0/messaging/health/messages/#{message_id}/draft", id: id, subject: msg.subject, category: msg.category,
                                                                 recipient_id: msg.recipient_id, body: body
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('message')
      expect(JSON.parse(response.body)['data']['attributes']['body']).to eq(body)
      expect(JSON.parse(response.body)['data']['attributes']['message_id']).to eq(message_id)
    end
  end

  describe '#thread' do
    let(:thread_id) { 573_059 }
    before(:each) do
      VCR.use_cassette("messages/#{id}/thread") do
        get "/v0/messaging/health/messages/#{thread_id}/thread"
      end
    end

    it 'responds to GET #thread' do
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('messages')
    end
  end
end
