# frozen_string_literal: true

require 'rails_helper'
require 'fileutils'
RSpec.describe TokenStorageService, type: :service do
  subject { described_class.new }

  let(:current_user) { build(:user, :loa1) }

  before do
    @token_hash = { access_token: '123', refresh_token: '454', scope: 'activities sleep', expires_in: '08880' }
    @token_hash_with_payload_key = { payload: @token_hash }
    @token_json = JSON.dump(@token_hash)
    @token_json_with_payload_key = { payload: @token_hash }.to_json
    @json_file = Aws::S3::Types::Object.new(key: 'file.json')
    @non_json_file = Aws::S3::Types::Object.new(key: 'file.txt')
    @token_as_string_io = StringIO.new(@token_json_with_payload_key)
    @token_s3_object = Aws::S3::Types::GetObjectOutput.new(body: @token_as_string_io)
    @aws_resp_no_content = Aws::S3::Types::ListObjectsV2Output.new(contents: [])
    @aws_resp_no_json = Aws::S3::Types::ListObjectsV2Output.new(contents: [@non_json_file])
    @files_resp_with_token = Aws::S3::Types::ListObjectsV2Output.new(contents: [@json_file])
    @device_key = 'fitbit'
  end

  describe 'token_storage_service#store_tokens' do
    context 'while deployed' do
      before do
        aws_resp = Aws::S3::Types::PutObjectOutput.new(etag: 'test')
        @s3_client = instance_double(Aws::S3::Client)
        allow(Aws::S3::Client).to receive(:new).and_return(@s3_client)
        allow(@s3_client).to receive(:put_object).with(any_args).and_return(aws_resp)
        allow(Settings).to receive(:vsp_environment).and_return('environment')
      end

      it 'return error when payload is not hash' do
        expect { subject.store_tokens(current_user, @device_key, @token_json) }.to raise_error(TokenStorageError)
      end

      it 'return error when when payload is hash but token exchange not successful' do
        aws_resp_no_etag = Aws::S3::Types::PutObjectOutput.new
        allow(@s3_client).to receive(:put_object).with(any_args).and_return(aws_resp_no_etag)
        expect(Settings.vsp_environment).to eq('environment')
        expect { subject.store_tokens(current_user, @device_key, @token_hash) }.to raise_error(TokenStorageError)
      end

      it 'returns true when when payload is hash and the upload to S3 was successful' do
        expect(subject.store_tokens(current_user, @device_key, @token_hash)).to eq(true)
      end
    end

    context 'while developing locally' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return(nil)
        allow_any_instance_of(File).to receive(:write).with(any_args).and_return(@token_json)
        allow_any_instance_of(File).to receive(:read).with(any_args).and_return(@token_json)
      end

      it 'returns true when the token was stored locally' do
        allow_any_instance_of(File).to receive(:write).with(any_args).and_return(@token_json)
        allow_any_instance_of(File).to receive(:read).with(any_args).and_return(@token_json)

        expect(subject.store_tokens(current_user, @device_key, @token_hash)).to eq(true)
      end

      it 'returns error when token was not stored locally' do
        allow_any_instance_of(File).to receive(:write).with(any_args).and_raise(TokenStorageError)
        allow_any_instance_of(File).to receive(:read).with(any_args).and_raise(TokenStorageError)

        expect { subject.store_tokens(current_user, @device_key, @token_hash) }.to raise_error(TokenStorageError)
      end
    end
  end

  describe 'token_storage_service#unpack_payload' do
    it 'returns unpacks the payload' do
      result = subject.send(:unpack_payload, @token_hash) # access private method
      expect(result).to include('123')
      expect(result).to include('454')
      expect(result).to include('activities,sleep')
      expect(result).to include('08880')
      expect(result).to include('received_at')
    end

    it 'throws a error when unpacking invalid payload' do
      expect { subject.send(:unpack_payload, @token_json) }.to raise_error(TokenStorageError)
    end
  end

  describe 'select_token_file' do
    it 'chooses the file with json extension' do
      file_list = [@json_file, @non_json_file]
      expect(subject.send(:select_token_file, file_list)).to eq(@json_file)
    end

    it 'throws an error if there is no file with extension .json  in folder' do
      expect { subject.send(:select_token_file, [@non_json_file]) }.to raise_error(TokenRetrievalError)
    end
  end

  describe 'lists_files_in_bucket' do
    it 'throws an error when the response has no content' do
      client = instance_double(Aws::S3::Client)
      allow(client).to receive(:list_objects_v2).with(any_args).and_return(@aws_resp_no_content)
      allow(Aws::S3::Client).to receive(:new).and_return(client)
      expect { subject.send(:lists_files_in_bucket, 'empty-bucket-key') }.to raise_error(TokenRetrievalError)
    end
  end

  describe 'get_token_file' do
    it 'throws an error if the file does not exit' do
      client = instance_double(Aws::S3::Client)
      allow(client).to receive(:get_object).with(any_args).and_raise(StandardError)
      allow(Aws::S3::Client).to receive(:new).and_return(client)
      expect { subject.send(:get_token_file, 'non-existent-key') }.to raise_error(TokenRetrievalError)
    end
  end

  describe 'get_token' do
    context 'while deployed' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('environment')
      end

      it 'returns token as hash when token json file present in s3' do
        client = instance_double(Aws::S3::Client)
        allow(client).to receive(:list_objects_v2).with(any_args).and_return(@files_resp_with_token)
        allow(client).to receive(:get_object).with(any_args).and_return(@token_s3_object)
        allow(Aws::S3::Client).to receive(:new).and_return(client)
        expect(subject.get_token(current_user, @device_key)).to eq @token_hash_with_payload_key
      end

      it 'raises TokenRetrieval Error when no files in S3 folder' do
        client = instance_double(Aws::S3::Client)
        allow(client).to receive(:list_objects_v2).with(any_args).and_return(@aws_resp_no_content)
        allow(Aws::S3::Client).to receive(:new).and_return(client)
        expect { subject.get_token(current_user, @device_key) }.to raise_error(TokenRetrievalError)
      end

      it 'raises TokenRetrieval Error when no json files in folder' do
        client = instance_double(Aws::S3::Client)
        allow(client).to receive(:list_objects_v2).with(any_args).and_return(@aws_resp_no_json)
        allow(Aws::S3::Client).to receive(:new).and_return(client)
        expect { subject.get_token(current_user, @device_key) }.to raise_error(TokenRetrievalError)
      end

      it 'raises TokenRetrieval Error when error fetching token json file from S3' do
        client = instance_double(Aws::S3::Client)
        allow(client).to receive(:list_objects_v2).with(any_args).and_return(@files_resp_with_token)
        allow(client).to receive(:get_object).with(any_args).and_raise(StandardError)
        allow(Aws::S3::Client).to receive(:new).and_return(client)
        expect { subject.get_token(current_user, @device_key) }.to raise_error(TokenRetrievalError)
      end
    end

    context 'while developing locally' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return(nil)
      end

      it 'returns token when token file is present in tmp folder' do
        allow(File).to receive(:open).and_return(@token_as_string_io)
        expect(subject.get_token(current_user, @device_key)).to eq(@token_hash_with_payload_key)
      end

      it 'returns TokenRetrievalError when token file is not present' do
        allow_any_instance_of(File).to receive(:read).with(any_args).and_raise(TokenRetrievalError)
        expect { subject.get_token(current_user, @device_key) }.to raise_error(TokenRetrievalError)
      end
    end
  end

  describe 'delete_token' do
    context 'while deployed' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('environment')
      end

      it 'deletes token from S3' do
        client = instance_double(Aws::S3::Client)
        delete_success_output = Aws::S3::Types::DeleteObjectOutput.new(delete_marker: true)
        allow(client).to receive(:delete_object).with(any_args).and_return(delete_success_output)
        allow(Aws::S3::Client).to receive(:new).and_return(client)
        expect(subject.delete_token(current_user, @device_key)).to eq(true)
      end

      it 'raises TokenDeletionError when the token is not deleted' do
        client = instance_double(Aws::S3::Client)
        delete_failure_output = Aws::S3::Types::DeleteObjectOutput.new(delete_marker: false)
        allow(client).to receive(:delete_object).with(any_args).and_return(delete_failure_output)
        allow(Aws::S3::Client).to receive(:new).and_return(client)
        expect { subject.delete_token(current_user, @device_key) }.to raise_error(TokenDeletionError)
      end
    end

    context 'while developing locally' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return(nil)
      end

      it 'deletes token locally when token file is present' do
        allow(File).to receive(:delete).and_return(1)
        expect(subject.delete_token(current_user, @device_key)).to eq(true)
      end

      it 'returns TokenDeletionError when token file is not present' do
        allow(File).to receive(:delete).and_raise(StandardError)
        expect { subject.delete_token(current_user, @device_key) }.to raise_error(TokenDeletionError)
      end
    end
  end
end
