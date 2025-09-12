# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'

describe 'sm client' do
  describe 'folders' do
    subject(:client) { @client }

    before do
      VCR.use_cassette 'sm_client/session' do
        @client ||= begin
          client = SM::Client.new(session: { user_uuid: '12345', user_id: '10616687' })
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

    context 'when not caching' do
      it 'does not cache folders' do
        VCR.use_cassette 'sm_client/folders/gets_a_collection_of_folders' do
          allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_no_cache).and_return(true)
          client.get_folders('1234', false)
          expect(Folder.get_cached('1234-folders')).to be_nil
        end
      end
    end

    context 'when caching' do
      it 'does cache folders' do
        VCR.use_cassette 'sm_client/folders/gets_a_collection_of_folders' do
          allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_no_cache).and_return(false)
          client.get_folders('1234', false)
          expect(Folder.get_cached('1234-folders').class).to eq(Array)
        end
      end
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

      context 'when not caching' do
        it 'does not cache messages' do
          VCR.use_cassette 'sm_client/folders/nested_resources/gets_a_collection_of_messages' do
            allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_no_cache).and_return(true)
            client.get_folder_messages('1234', folder_id, false)
            expect(Folder.get_cached("1234-folder-messages-#{folder_id}")).to be_nil
          end
        end
      end

      context 'when caching' do
        it 'does cache messages' do
          VCR.use_cassette 'sm_client/folders/nested_resources/gets_a_collection_of_messages' do
            allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_no_cache).and_return(false)
            client.get_folder_messages('1234', folder_id, false)
            expect(Folder.get_cached("1234-folder-messages-#{folder_id}").class).to eq(Array)
          end
        end
      end
    end
  end
end
