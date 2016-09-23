# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Message Drafts Integration', type: :request do
  let(:user_id) { ENV['MHV_SM_USER_ID'] }

  let(:msg) { { message_draft: attributes_for(:message) } }
  let(:msg_wo_subj) { { message_draft: attributes_for(:message).except(:subject) } }

  describe 'creating a draft' do
    it 'responds to POST #create' do
      VCR.use_cassette("sm/message_drafts/#{user_id}/create") do
        post '/v0/messaging/health/message_drafts', msg
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('message')
    end

    it 'fills in subject if one is missing' do
      VCR.use_cassette("sm/message_drafts/#{user_id}/create_missing_subject") do
        post '/v0/messaging/health/message_drafts', msg_wo_subj
      end

      expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('General Inquiry')
    end
  end

  describe 'updating a draft' do
    it 'responds to PUT #draft' do
      VCR.use_cassette("sm/message_drafts/#{user_id}/update") do
        post '/v0/messaging/health/message_drafts', msg

        msg[:message_draft][:id] = JSON.parse(response.body)['data']['attributes']['message_id']
        msg[:message_draft][:body] += '. This is the added bit!'

        put "/v0/messaging/health/message_drafts/#{msg[:message_draft][:id]}", msg

        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('message')
      end
    end
  end
end
