# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'

describe 'sm client' do
  describe 'message drafts' do
    before(:all) do
      VCR.use_cassette 'sm_client/session', record: :new_episodes do
        @client ||= begin
          client = SM::Client.new(session: { user_id: ENV['MHV_SM_USER_ID'] })
          client.authenticate
          client
        end
      end
    end

    let(:client)       { @client }
    let(:reply_id)     { 631_270 }
    let(:draft)        { attributes_for(:message, body: 'Body 1', subject: 'Subject 1') }
    let(:draft_params) { draft.slice(:category, :subject, :body, :recipient_id) }

    it 'creates and updates new message draft', :vcr do
      message_draft = client.post_create_message_draft(draft_params)
      expect(message_draft).to be_a(MessageDraft)
      expect(message_draft.subject).to eq('Subject 1')

      draft_params[:id] = message_draft.id
      draft_params[:subject] = 'Updated Subject'

      updated_message_draft = client.post_create_message_draft(draft_params)
      expect(updated_message_draft).to be_a(MessageDraft)
      expect(updated_message_draft.subject).to eq('Updated Subject')
      expect(updated_message_draft.id).to eq(message_draft.id)
    end

    it 'creates and updates new message draft reply', :vcr do
      message_draft_reply = client.post_create_message_draft_reply(reply_id, draft_params)
      expect(message_draft_reply).to be_a(MessageDraft)
      expect(message_draft_reply.body).to eq('Body 1')

      draft_params[:id] = message_draft_reply.id
      draft_params[:body] = 'Updated Body'

      updated_message_draft_reply = client.post_create_message_draft_reply(reply_id, draft_params)
      expect(updated_message_draft_reply).to be_a(MessageDraft)
      expect(updated_message_draft_reply.body).to eq('Updated Body')
      expect(updated_message_draft_reply.id).to eq(message_draft_reply.id)
    end
  end
end
