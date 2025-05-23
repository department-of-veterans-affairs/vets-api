# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'

describe 'sm client' do
  describe 'folders' do
    subject(:client) { @client }

    before do
      VCR.use_cassette 'sm_client/session' do
        @client ||= begin
          client = SM::Client.new(session: { user_id: '10616687' })
          client.authenticate
          client
        end
      end
    end

    let(:folder_name) { "test folder #{rand(100..100_000)}" }
    let(:folder_id)   { 0 }

    it 'gets a collection of folders', :vcr do
      folders = client.get_folders('1234', false)
      expect(folders).to be_a(Vets::Collection)
      expect(folders.type).to eq(Folder)
    end

    it 'gets a single folder', :vcr do
      folder = client.get_folder(folder_id)
      expect(folder).to be_a(Folder)
    end

    it 'creates a folder and deletes a folder', :vcr do
      created_folder = client.post_create_folder(folder_name)
      expect(created_folder).to be_a(Folder)

      client_response = client.delete_folder(created_folder.id)
      expect(client_response).to eq(200)
    end

    context 'nested resources' do
      it 'gets a collection of messages (mhv max)', :vcr do
        # set the max pages to 1 for testing purposes
        stub_const('SM::Client::MHV_MAXIMUM_PER_PAGE', 2)
        # There are 10 records, 2 per page, so it should loop 6 times making requests
        expect(client).to receive(:perform).and_call_original.exactly(6).times
        messages = client.get_folder_messages('1234', folder_id, false)
        expect(messages).to be_a(Vets::Collection)
        expect(messages.records.size).to eq(10)
      end

      it 'gets a collection of messages', :vcr do
        expect(client).to receive(:perform).and_call_original.once
        messages = client.get_folder_messages('1234', folder_id, false)
        expect(messages).to be_a(Vets::Collection)
        expect(messages.records.size).to eq(10)
      end
    end
  end
end
