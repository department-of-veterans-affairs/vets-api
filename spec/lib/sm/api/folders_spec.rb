# frozen_string_literal: true
require 'sm/client'

require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

describe SM::Client do
  include SM::ClientHelpers

  subject(:client) { authenticated_client }

  describe 'get_folders' do
    context 'with valid session and configuration' do
      it 'gets a collection of folders' do
        VCR.use_cassette('sm/folders/10616687/index') do
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
        VCR.use_cassette('sm/folders/10616687/show') do
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
        VCR.use_cassette('sm/folders/10616687/create_valid') do
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
        VCR.use_cassette('sm/folders/10616687/delete_valid') do
          # cassette_setup = client.post_create_folder(name)
          client_response = client.delete_folder(613_557)
          expect(client_response).to eq(200)
        end
      end
    end
  end
end
