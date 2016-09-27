# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

describe SM::Client do
  include SM::ClientHelpers

  subject(:client) { authenticated_client }
  let(:user_id) { 10_616_687 }
  let(:draft_to_update) { 573_073 }

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
end
