# frozen_string_literal: true

require 'rails_helper'
require 'fileutils'
RSpec.describe TokenStorageService, type: :service do
  subject { described_class.new }

  let(:current_user) { build(:user, :loa1) }

  token_hash = { access_token: '123', refresh_token: '454', scope: 'activities sleep', expires_in: '08880' }
  token_json = JSON.dump(token_hash)
  device_key = 'fitbit'

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
        expect { subject.store_tokens(current_user, device_key, token_json) }.to raise_error(TokenStorageError)
      end

      it 'return error when when payload is hash but token exchange not successful' do
        aws_resp_no_etag = Aws::S3::Types::PutObjectOutput.new
        allow(@s3_client).to receive(:put_object).with(any_args).and_return(aws_resp_no_etag)
        expect(Settings.vsp_environment).to eq('environment')
        expect { subject.store_tokens(current_user, device_key, token_hash) }.to raise_error(TokenStorageError)
      end

      it 'returns true when when payload is hash and the upload to S3 was successful' do
        expect(subject.store_tokens(current_user, device_key, token_hash)).to eq(true)
      end
    end

    context 'while developing locally' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return(nil)
        allow_any_instance_of(File).to receive(:write).with(any_args).and_return(token_json)
        allow_any_instance_of(File).to receive(:read).with(any_args).and_return(token_json)
      end

      it 'returns true when the token was stored locally' do
        allow_any_instance_of(File).to receive(:write).with(any_args).and_return(token_json)
        allow_any_instance_of(File).to receive(:read).with(any_args).and_return(token_json)

        expect(subject.store_tokens(current_user, device_key, token_hash)).to eq(true)
      end

      it 'returns error when token was not stored locally' do
        allow_any_instance_of(File).to receive(:write).with(any_args).and_raise(TokenStorageError)
        allow_any_instance_of(File).to receive(:read).with(any_args).and_raise(TokenStorageError)

        expect { subject.store_tokens(current_user, device_key, token_hash) }.to raise_error(TokenStorageError)
      end
    end
  end

  describe 'token_storage_service#unpack_payload' do
    it 'returns unpacks the payload' do
      result = subject.send(:unpack_payload, token_hash) # access private method
      expect(result).to include('123')
      expect(result).to include('454')
      expect(result).to include('activities,sleep')
      expect(result).to include('08880')
      expect(result).to include('received_at')
    end

    it 'throws a error when unpacking invalid payload' do
      expect { subject.send(:unpack_payload, token_json) }.to raise_error(TokenStorageError)
    end
  end
end
