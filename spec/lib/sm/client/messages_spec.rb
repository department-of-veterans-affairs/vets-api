# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'

describe 'sm client' do
  describe 'messages' do

    # Ensure Flipper is mocked before the VCR block - remove this when AWS API GW is fully implemented
before do
  allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_migrate_to_api_gateway).and_return(false)
end

    before do
      VCR.use_cassette 'sm_client/session' do
        @client ||= begin
          client = SM::Client.new(session: { user_id: '10616687' })
          client.authenticate
          client
        end
      end
    end

    let(:client)              { @client }
    let(:existing_message_id) { 573_059 }
    let(:move_message_id)     { 573_052 }
    let(:destroy_message_id)  { 573_052 }
    let(:existing_folder_id)  { 610_965 }

    it 'raises an error when a service outage exists', :vcr do
      SM::Configuration.instance.breakers_service.begin_forced_outage!
      expect { client.get_message(existing_message_id) }
        .to raise_error(Breakers::OutageException)
      SM::Configuration.instance.breakers_service.end_forced_outage!
    end

    it 'deletes the message with id', :vcr do
      expect(client.delete_message(destroy_message_id)).to eq(200)
    end

    # Move the previously deleted message back to the inbox
    it 'moves a message with id', :vcr do
      expect(client.post_move_message(move_message_id, 0)).to eq(200)
    end

    it 'gets a message with id', :vcr do
      message = client.get_message(existing_message_id)
      expect(message.attributes[:id]).to eq(existing_message_id)
      expect(message.attributes[:subject].strip).to eq('Quote test: “test”')
    end

    it 'gets a message thread', :vcr do
      thread = client.get_message_history(existing_message_id)
      expect(thread).to be_a(Common::Collection)
      expect(thread.members.size).to eq(2)
    end

    it 'gets message categories', :vcr do
      categories = client.get_categories
      expect(categories).to be_a(Category)
      expect(categories.message_category_type).to contain_exactly(
        'OTHER', 'APPOINTMENTS', 'MEDICATIONS', 'TEST_RESULTS', 'EDUCATION'
      )
    end

    context 'creates' do
      before do
        VCR.use_cassette 'sm_client/messages/creates/a_new_message_without_attachments' do
          message_attributes = attributes_for(:message, subject: 'CI Run', body: 'Continuous Integration')
          @params = message_attributes.slice(:subject, :category, :recipient_id, :body)
          @created_message = @client.post_create_message(@params)
        end
      end

      let(:created_message)       { @created_message }
      let(:attachment_type)       { 'image/jpg' }
      let(:uploads) do
        [
          Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file1.jpg', attachment_type),
          Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file2.jpg', attachment_type),
          Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file3.jpg', attachment_type),
          Rack::Test::UploadedFile.new('spec/fixtures/files/sm_file4.jpg', attachment_type)
        ]
      end
      let(:params) { @params }
      let(:params_with_attachments) { { message: params }.merge(uploads:) }

      it 'a new message without attachments' do
        expect(created_message).to be_a(Message)
      end

      it 'a reply without attachments', :vcr do
        reply_message = client.post_create_message_reply(created_message.id, params)
        expect(reply_message).to be_a(Message)
      end

      it 'a new message with 4 attachments', :vcr do
        message = client.post_create_message_with_attachment(params_with_attachments)

        expect(message).to be_a(Message)
        expect(message.attachments.size).to eq(4)
        expect(message.attachments[0]).to be_an(Attachment)
      end

      it 'a reply with 4 attachments', :vcr do
        message = client.post_create_message_reply_with_attachment(created_message.id, params_with_attachments)

        expect(message).to be_a(Message)
        expect(message.attachments.size).to eq(4)
        expect(message.attachments[0]).to be_an(Attachment)
      end

      it 'cannot send reply draft as message', :vcr do
        draft = attributes_for(:message_draft, id: 655_623).slice(:id, :subject, :body, :recipient_id)
        expect { client.post_create_message(draft) }.to raise_error(Common::Exceptions::ValidationErrors)
      end

      it 'cannot send draft as reply', :vcr do
        draft = attributes_for(:message_draft, id: 655_626).slice(:id, :subject, :body, :recipient_id)
        expect { client.post_create_message_reply(631_270, draft) }.to raise_error(Common::Exceptions::ValidationErrors)
      end
    end

    context 'nested resources' do
      let(:message_id)    { 629_999 }
      let(:attachment_id) { 629_993 }

      it 'gets a single attachment by id', :vcr do
        attachment = client.get_attachment(message_id, attachment_id)

        expect(attachment[:filename]).to eq('noise300x200.png')
        expect(attachment[:body].encoding.to_s).to eq('ASCII-8BIT')
      end

      it 'gets a single attachment with quotes in filename', :vcr do
        attachment = client.get_attachment(message_id, attachment_id)
        expect(attachment[:filename]).to eq('noise300x200.png')
      end
    end
  end
end
