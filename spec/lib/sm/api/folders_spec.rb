# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

describe SM::Client do
  include SM::ClientHelpers

  subject(:client) { authenticated_client }

  describe 'get_folders' do
    context 'with valid session and configuration' do
      it 'gets a collection of folders' do
        VCR.use_cassette('sm/folders/responds_to_GET_index') do
          client_response = client.get_folders
          expect(client_response).to be_a(Common::Collection)
          expect(client_response.type).to eq(Folder)
        end
      end
    end
  end

  describe 'get_folder' do
    context 'with valid session and configuration' do
      let(:id) { 0 }

      it 'gets a single folder' do
        VCR.use_cassette('sm/folders/responds_to_GET_show') do
          client_response = client.get_folder(id)
          expect(client_response).to be_a(Folder)
        end
      end
    end
  end

  describe 'post_create_folder' do
    context 'with valid characters in name' do
      let(:name) { "test folder create name #{Time.now.utc.strftime('%y%m%d%H%M%S')}" }

      it 'creates a folder with given name' do
        VCR.use_cassette('sm/folders/non_idempotent_actions/responds_to_POST_create') do
          client_response = client.post_create_folder(name)
          expect(client_response).to be_a(Folder)
        end
      end
    end
  end

  describe 'delete_folder' do
    let(:name) { "test folder delete name #{Time.now.utc.strftime('%y%m%d%H%M%S')}" }

    context 'with a valid id' do
      it 'deletes the folder and returns 200' do
        VCR.use_cassette('sm/folders/non_idempotent_actions/responds_to_DELETE_destroy') do
          client_response = client.delete_folder(653_164)
          expect(client_response).to eq(200)
        end
      end
    end
  end

  describe 'nested resources' do
    describe 'responds to GET index of messages' do
      it 'does 3 total requests and returns 5 results' do
        VCR.use_cassette('sm/folders/nested_resources/responds_to_GET_index_of_messages/makes_multiple_requests') do
          # set the max pages to 1 for testing purposes
          stub_const('SM::API::Folders::MHV_MAXIMUM_PER_PAGE', 2)
          # There are 5 records, 2 per page, so it should loop 3 times making requests
          expect(client).to receive(:perform).and_call_original.exactly(3).times
          client_response = client.get_folder_messages(0)
          expect(client_response).to be_a(Common::Collection)
          expect(client_response.data.size).to eq(5)
        end
      end
    end
  end
end
