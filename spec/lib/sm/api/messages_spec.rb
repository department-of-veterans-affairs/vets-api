# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

describe SM::Client do
  include SM::ClientHelpers

  subject(:client) { authenticated_client }

  describe 'get_message' do
    context 'with valid id' do
      let(:id) { 573_302 }
      let(:message_subj) { 'Release 16.2- SM last login' }
      let(:client_response) do
        VCR.use_cassette('sm/messages/10616687/show') do
          client.get_message(id)
        end
      end

      it 'gets a message by message id' do
        expect(client_response.attributes[:id]).to eq(id)
        expect(client_response.attributes[:subject].strip).to eq(message_subj)
      end

      it 'marks a message read' do
        expect(client_response.attributes[:read_receipt]).to eq('READ')
      end
    end
  end

  describe 'get_message_history' do
    context 'with valid id' do
      # Note history does not seem to work with a new message and new replay
      let(:id) { 573_059 }

      let(:client_response) do
        VCR.use_cassette('sm/messages/10616687/thread') do
          client.get_message_history(id)
        end
      end

      it 'gets a message by message id' do
        expect(client_response.data.class).to eq(Array)
        expect(client_response.data.size).to eq(2)
      end
    end
  end

  describe 'get_message_category' do
    let(:client_response) do
      VCR.use_cassette('sm/messages/10616687/category') do
        client.get_message_category
      end
    end

    it 'retrieves an array of categories' do
      expect(client_response).to be_a(Category)
      expect(client_response.message_category_type).to contain_exactly(
        'OTHER', 'APPOINTMENTS', 'MEDICATIONS', 'TEST_RESULTS', 'EDUCATION'
      )
    end
  end

  describe 'post_create_message_draft' do
    let(:new_draft) do
      attributes_for(:message).slice(:subject, :recipient_id, :category, :body)
    end

    context 'with valid attributes' do
      it 'creates a new draft without attachments' do
        VCR.use_cassette('sm/messages/10616687/create_draft') do
          client_response = client.post_create_message_draft(new_draft)
          expect(client_response).to be_a(Message)
        end
      end

      it 'updates an existing draft' do
        VCR.use_cassette('sm/messages/10616687/update_draft') do
          new_draft[:id] = 620_096
          new_draft[:body] = 'Updated Body'
          client_response = client.post_create_message_draft(new_draft)
          expect(client_response).to be_a(Message)
        end
      end
    end
  end

  describe 'post_create_message' do
    let(:new_message) do
      attributes_for(:message).slice(:subject, :recipient_id, :category, :body)
    end

    context 'with valid attributes' do
      it 'creates and sends a new message without attachments' do
        VCR.use_cassette('sm/messages/10616687/create') do
          client_response = client.post_create_message(new_message)
          expect(client_response).to be_a(Message)
        end
      end

      it 'sends a draft message without attachments' do
        VCR.use_cassette('sm/messages/10616687/create_message_from_draft') do
          new_message[:id] = 610_105

          client_response = client.post_create_message(new_message)
          expect(client_response).to be_a(Message)
        end
      end
    end
  end

  describe 'post_create_message_reply' do
    context 'with a non-draft reply with valid attributes and without attachements' do
      let(:reply_body) { 'This is a reply body' }

      it 'replies to a message by id' do
        VCR.use_cassette('sm/messages/10616687/create_message_reply') do
          # cassette_setup = client.post_create_message(attributes_for(:message).slice(:body))
          client_response = client.post_create_message_reply(610_114, body: reply_body)
          expect(client_response).to be_a(Message)
        end
      end
    end
  end

  describe 'move_message' do
    let(:msg_id) { 573_034 }

    context 'with valid id' do
      it 'moves the message' do
        VCR.use_cassette('sm/messages/10616687/move') do
          expect(client.post_move_message(msg_id)).to eq(200)
        end
      end
    end
  end

  describe 'delete_message' do
    let(:msg_id) { 573_034 }

    context 'with valid id' do
      it 'deletes the message' do
        VCR.use_cassette('sm/messages/10616687/delete') do
          expect(client.delete_message(msg_id, 3)).to eq(200)
        end
      end
    end
  end
end
