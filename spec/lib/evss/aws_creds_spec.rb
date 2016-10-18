# frozen_string_literal: true
require 'rails_helper'

describe EVSS::AwsCreds do
  describe '.fetch' do
    context 'when fetch_from_remote is true' do
      it 'should return a hash from the metadata' do
        aws_creds = {
          'AccessKeyId' => 'aws_access_key_id',
          'SecretAccessKey' => 'aws_secret_access_key'
        }
        stub_request(:any, EVSS::AwsCreds::METADATA_ENDPOINT)
          .to_return(body: aws_creds.to_json)
        expect(EVSS::AwsCreds.fetch(true)).to eq(aws_access_key_id: 'aws_access_key_id',
                                                 aws_secret_access_key: 'aws_secret_access_key')
      end
    end

    context 'when fetch_from_remote is false' do
      it 'should return nil' do
        expect(EVSS::AwsCreds.fetch(false)).to eq(nil)
      end
    end
  end
end
