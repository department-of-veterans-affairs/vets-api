# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'

describe SM::Client do
  let(:config) { SM::Configuration.new(attributes_for(:configuration)) }
  let(:session) { SM::ClientSession.new(attributes_for(:session, :valid_user)) }
  let(:user_id) { 10_616_687 }

  before(:each) do
    @client = SM::Client.new(config: config, session: session)
  end

  describe 'post_create_message_draft' do
    let(:draft) { attributes_for(:message).except(:id) }

    it 'creates a new draft without attachments' do
      VCR.use_cassette("sm/message_drafts/#{user_id}/create") do
        @client.authenticate
        client_response = @client.post_create_message_draft(draft)

        expect(client_response).to be_a(MessageDraft)
      end
    end

    it 'updates an existing draft' do
      VCR.use_cassette("sm/message_drafts/#{user_id}/update") do
        @client.authenticate
        msg = @client.post_create_message_draft(draft)
        msg.attributes[:body] = ". This is the added bit!"

        client_response = @client.post_create_message_draft(msg.attributes)
        expect(client_response).to be_a(MessageDraft)
      end
    end
  end
end
