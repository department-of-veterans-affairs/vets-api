# frozen_string_literal: true
require 'sm/client'

describe SM::Client do
  let(:session) { SM::ClientSession.new(attributes_for(:session, :valid_user)) }

  describe 'get_folders' do
    context 'with valid session and configuration' do
      it 'gets a collection of folders' do
        VCR.use_cassette('sm/folders/10616687/index') do
          client = SM::Client.new(session: session)
          client.authenticate

          folders = client.get_folders
          keys = folders.data.first.attributes.keys
          expect(folders.data).to_not be_empty
          expect(folders.type).to eq(Folder)
          expect(keys).to contain_exactly(:id, :name, :count, :unread_count, :system_folder)
        end
      end
    end
  end

  describe 'get_folder' do
    context 'with valid session and configuration' do
      let(:id) { 0 }

      before(:each) do
        VCR.use_cassette('sm/folders/10616687/show') do
          client = SM::Client.new(session: session)
          client.authenticate

          @folder = client.get_folder(id)
        end
      end

      it 'gets a single folder' do
        keys = @folder.attributes.keys
        expect(keys).to contain_exactly(:id, :name, :count, :unread_count, :system_folder)
      end
    end
  end

  describe 'post_create_folder' do
    context 'with valid characters in name' do
      let(:name) { "test folder create name #{Time.now.utc.strftime('%y%m%d%H%M%S')}" }

      before(:each) do
        VCR.use_cassette('sm/folders/10616687/create_valid') do
          client = SM::Client.new(session: session)
          client.authenticate

          @folder = client.post_create_folder(name)
        end
      end

      it 'creates a folder with given name' do
        keys = @folder.attributes.keys

        expect(keys).to contain_exactly(:id, :name, :count, :unread_count, :system_folder)
      end
    end
  end

  describe 'delete_folder' do
    let(:name) { "test folder delete name #{Time.now.utc.strftime('%y%m%d%H%M%S')}" }

    context 'with a valid id' do
      it 'deletes the folder and returns 200' do
        VCR.use_cassette('sm/folders/10616687/delete_valid') do
          client = SM::Client.new(session: session)
          client.authenticate

          folder = client.post_create_folder(name)
          response = client.delete_folder(folder.id)

          expect(response).to eq(200)
        end
      end
    end
  end
end
