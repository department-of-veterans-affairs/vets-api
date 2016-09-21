# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Message Drafts Integration', type: :request do
  let(:user_id) { ENV['MHV_SM_USER_ID'] }
  let(:msg) { build :message }

  before(:each) do
    VCR.use_cassette("sm/message_drafts/#{user_id}/create") do
      post '/v0/messaging/health/message_drafts', subject: msg.subject, category: msg.category,
                                                  recipient_id: msg.recipient_id, body: msg.body

      @org = JSON.parse(response.body)['data']['attributes']
      @body = @org['body'] + '. This is the added bit!'
      @message_id = @org['message_id']
    end
  end

  describe 'creating a draft' do
    it 'responds to POST #create' do
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('message')
    end
  end

  describe 'updating a draft' do
    it 'responds to PUT #draft' do
      VCR.use_cassette("sm/message_drafts/#{user_id}/update") do
        put "/v0/messaging/health/message_drafts/#{@message_id}", subject: msg.subject, category: msg.category,
                                                                  body: @body, recipient_id: msg.recipient_id
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('message')
      expect(JSON.parse(response.body)['data']['attributes']['body']).to eq(@body)
      expect(JSON.parse(response.body)['data']['attributes']['message_id']).to eq(@message_id)
    end
  end
end
