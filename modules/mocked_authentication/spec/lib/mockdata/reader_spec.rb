# frozen_string_literal: true

require 'rails_helper'
require 'mockdata/reader'

describe MockedAuthentication::Mockdata::Reader do
  describe '.find_credentials' do
    subject do
      MockedAuthentication::Mockdata::Reader.find_credentials(credential_type:)
    end

    let(:credential_type) { 'logingov' }
    let(:vets_api_mockdata_stub) do
      File.join(MockedAuthentication::Engine.root, 'spec', 'fixtures', 'credential_mock_data')
    end
    let(:mock_creds_filepath) { File.join(vets_api_mockdata_stub, 'credentials', credential_type) }

    let(:mock_user_zero) { File.read("#{mock_creds_filepath}/#{mock_user_zero_identifier}.json") }
    let(:mock_user_zero_identifier) { 'vetsgovuser0' }
    let(:mock_user_zero_mpi_mock_exists) { true }

    let(:mock_user_one) { File.read("#{mock_creds_filepath}/#{mock_user_one_identifier}.json") }
    let(:mock_user_one_identifier) { 'vetsgovuser1' }
    let(:mock_user_one_mpi_mock_exists) { false }

    let(:expected_hash) do
      {
        mock_user_zero_identifier => {
          encoded_credential: Base64.encode64(mock_user_zero),
          credential_payload: JSON.parse(mock_user_zero),
          mpi_mock_exists: mock_user_zero_mpi_mock_exists
        },
        mock_user_one_identifier => {
          encoded_credential: Base64.encode64(mock_user_one),
          credential_payload: JSON.parse(mock_user_one),
          mpi_mock_exists: mock_user_one_mpi_mock_exists
        }
      }
    end

    before { allow(Settings.betamocks).to receive(:cache_dir).and_return(vets_api_mockdata_stub) }

    it 'returns a hash of mocked credential data for expected users' do
      expect(subject).to eq(expected_hash)
    end
  end
end
