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
    let(:new_draft) do
      attributes_for(:message)
        .except(:id, :attachment, :sent_date, :sender_id, :sender_name, :recipient_name, :read_receipt)
    end

    context 'with valid attributes' do
      it 'creates a new draft without attachments' do
        VCR.use_cassette("sm/message_drafts/#{user_id}/create") do
          @client.authenticate
          msg = @client.post_create_message_draft(new_draft)

          expect(msg.attributes.keys).to contain_exactly(
            :id, :category, :subject, :body, :attachment, :sent_date, :sender_id,
            :sender_name, :recipient_id, :recipient_name, :read_receipt
          )
        end
      end

      it 'updates an existing draft' do
        VCR.use_cassette("sm/message_drafts/#{user_id}/update") do
          @client.authenticate
          draft = @client.post_create_message_draft(new_draft)

          new_draft[:id] = draft.id
          new_draft[:body] = draft.body + ' Now has been updated'

          msg = @client.post_create_message_draft(new_draft)

          expect(msg.attributes.keys).to contain_exactly(
            :id, :category, :subject, :body, :attachment, :sent_date, :sender_id,
            :sender_name, :recipient_id, :recipient_name, :read_receipt
          )
        end
      end
    end
  end
end
