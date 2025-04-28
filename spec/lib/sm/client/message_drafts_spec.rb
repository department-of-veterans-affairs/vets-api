# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'

describe SM::Client do
  # Ensure Flipper is mocked before the VCR block - remove this when AWS API GW is fully implemented
before do
  allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_migrate_to_api_gateway).and_return(false)
end

  describe 'message drafts' do
    before do
      VCR.use_cassette 'sm_client/session' do
        @client ||= begin
          client = SM::Client.new(session: { user_id: '10616687' })
          client.authenticate
          client
        end
      end
    end

    let(:client)       { @client }
    let(:reply_id)     { 674_874 }
    let(:draft)        { attributes_for(:message, body: 'Body 1', subject: 'Subject 1') }
    let(:draft_params) { draft.slice(:category, :subject, :body, :recipient_id) }

    it 'creates and updates new message draft', :vcr do
      message_draft = nil

      VCR.use_cassette 'sm_client/message_drafts/creates_a_draft' do
        message_draft = client.post_create_message_draft(draft_params)
        expect(message_draft).to be_a(MessageDraft)
        expect(message_draft.subject).to eq('Subject 1')
      end

      draft_params[:id] = message_draft.id
      draft_params[:subject] = 'Updated Subject'

      VCR.use_cassette 'sm_client/message_drafts/updates_a_draft' do
        updated_message_draft = client.post_create_message_draft(draft_params)
        expect(updated_message_draft).to be_a(MessageDraft)
        expect(updated_message_draft.subject).to eq('Updated Subject')
        expect(updated_message_draft.id).to eq(message_draft.id)
      end
    end

    it 'creates and updates new message draft reply' do
      message_draft_reply = nil

      VCR.use_cassette('sm_client/message_drafts/creates_a_draft_reply') do
        message_draft_reply = client.post_create_message_draft_reply(reply_id, draft_params)
        expect(message_draft_reply).to be_a(MessageDraft)
        expect(message_draft_reply.body).to eq('Body 1')
      end

      draft_params[:id] = message_draft_reply.id
      draft_params[:body] = 'Updated Body'

      VCR.use_cassette('sm_client/message_drafts/updates_a_draft_reply') do
        updated_message_draft_reply = client.post_create_message_draft_reply(reply_id, draft_params)
        expect(updated_message_draft_reply).to be_a(MessageDraft)
        expect(updated_message_draft_reply.body).to eq('Updated Body')
        expect(updated_message_draft_reply.id).to eq(message_draft_reply.id)
      end
    end
  end
end
