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

  describe 'post_create_message_draft' do
    let(:draft) { attributes_for(:message).slice(:category, :subject, :body, :recipient_id) }

    it 'creates a new draft without attachments' do
      VCR.use_cassette("sm/message_drafts/#{user_id}/create") do
        client_response = client.post_create_message_draft(draft)
        expect(client_response).to be_a(MessageDraft)
      end
    end

    it 'updates an existing draft' do
      VCR.use_cassette("sm/message_drafts/#{user_id}/update") do
        draft[:id] = draft_to_update
        draft[:subject] = 'Updated Subject'

        client_response = client.post_create_message_draft(draft)
        expect(client_response).to be_a(MessageDraft)
        expect(client_response.subject).to eq('Updated Subject')
      end
    end
  end

  describe 'post_create_message_draft_reply' do
    let(:draft) { attributes_for(:message).slice(:category, :subject, :body, :recipient_id) }

    it 'creates a new reply draft without attachments' do
      VCR.use_cassette("sm/message_drafts/#{user_id}/replydraft") do
        client_response = client.post_create_message_draft_reply(reply_id, draft)
        expect(client_response).to be_a(MessageDraft)
      end
    end

    it 'updates an existing reply draft body' do
      VCR.use_cassette("sm/message_drafts/#{user_id}/update_replydraft") do
        draft[:id] = replydraft_to_update
        draft[:body] = 'Updated Body'

        client_response = client.post_create_message_draft_reply(reply_id, draft)
        expect(client_response).to be_a(MessageDraft)
        expect(client_response.body).to eq('Updated Body')
      end
    end

    it 'does not update existing reply draft subject' do
      VCR.use_cassette("sm/message_drafts/#{user_id}/update_replydraft_subject") do
        draft[:id] = replydraft_to_update
        draft[:subject] = 'Updated Subject'
        draft[:body] = 'Updated Updated Body'

        client_response = client.post_create_message_draft_reply(reply_id, draft)
        expect(client_response).to be_a(MessageDraft)
        expect(client_response.body).to eq('Updated Updated Body')
        expect(client_response.subject).not_to eq('Updated Subject')
      end
    end
  end
end
