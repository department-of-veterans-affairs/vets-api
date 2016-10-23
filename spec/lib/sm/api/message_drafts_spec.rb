# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

describe SM::Client do
  include SM::ClientHelpers

  subject(:client) { authenticated_client }
  let(:user_id) { 10_616_687 }
  let(:draft_to_update) { 573_073 }
  let(:reply_id) { 631_270 }
  let(:replydraft_to_update) { 632_528 }
  let(:draft) { attributes_for(:message).slice(:category, :subject, :body, :recipient_id) }

  it 'should #post_create_message_draft to create new draft' do
    VCR.use_cassette('sm/message_drafts/responds_to_POST_create') do
      client_response = client.post_create_message_draft(draft)
      expect(client_response).to be_a(MessageDraft)
    end
  end

  it 'should #post_create_message_draft to update existing draft' do
    VCR.use_cassette('sm/message_drafts/responds_to_PUT_update') do
      draft[:id] = draft_to_update
      draft[:subject] = 'Updated Subject'

      client_response = client.post_create_message_draft(draft)
      expect(client_response).to be_a(MessageDraft)
      expect(client_response.subject).to eq('Updated Subject')
    end
  end

  it 'should #post_create_message_draft_reply to create new reply draft' do
    VCR.use_cassette('sm/reply_drafts/responds_to_POST_create') do
      client_response = client.post_create_message_draft_reply(reply_id, draft)
      expect(client_response).to be_a(MessageDraft)
    end
  end

  it 'should #post_create_message_draft_reply to update an existing reply draft' do
    VCR.use_cassette('sm/reply_drafts/responds_to_PUT_update') do
      draft[:id] = replydraft_to_update
      draft[:body] = 'Updated Body'

      client_response = client.post_create_message_draft_reply(reply_id, draft)
      expect(client_response).to be_a(MessageDraft)
      expect(client_response.body).to eq('Updated Body')
    end
  end
end
