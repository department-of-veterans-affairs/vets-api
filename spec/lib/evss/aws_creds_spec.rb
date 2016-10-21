# frozen_string_literal: true
require 'rails_helper'

describe EVSS::AwsCreds do
  describe '.fetch' do
    it 'should return a hash from the metadata' do
      aws_creds = {
        'AccessKeyId' => 'aws_access_key_id',
        'SecretAccessKey' => 'aws_secret_access_key'
      }
      stub_request(:any, EVSS::AwsCreds::METADATA_ENDPOINT)
        .to_return(body: aws_creds.to_json)
      expect(EVSS::AwsCreds.fetch).to eq(aws_access_key_id: 'aws_access_key_id',
                                         aws_secret_access_key: 'aws_secret_access_key')
    end

    context 'when fetch has already been called' do
      it 'should return the same creds' do
        aws_creds = {
          'AccessKeyId' => 'aws_access_key_id',
          'SecretAccessKey' => 'aws_secret_access_key'
        }
        stub_request(:any, EVSS::AwsCreds::METADATA_ENDPOINT)
          .to_return(body: aws_creds.to_json).then
          .to_return(body: nil)
        expect(EVSS::AwsCreds.fetch).to eq(aws_access_key_id: 'aws_access_key_id',
                                           aws_secret_access_key: 'aws_secret_access_key')
        expect(EVSS::AwsCreds.fetch).to eq(aws_access_key_id: 'aws_access_key_id',
                                           aws_secret_access_key: 'aws_secret_access_key')
      end
    end
  end
end
