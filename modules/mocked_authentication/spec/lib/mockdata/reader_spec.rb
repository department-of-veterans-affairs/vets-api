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
    let(:mock_user_zero) { File.read("#{mock_creds_filepath}/vetsgovuser0.json") }
    let(:mock_user_one) { File.read("#{mock_creds_filepath}/vetsgovuser1.json") }
    let(:mock_user_two_two_eight) { File.read("#{mock_creds_filepath}/vetsgovuser228.json") }
    let(:expected_mock_data) do
      { 'vetsgovuser0' => { 'credential_payload' => JSON.parse(mock_user_zero),
                            'encoded_credential' => Base64.encode64(mock_user_zero) },
        'vetsgovuser1' => { 'credential_payload' => JSON.parse(mock_user_one),
                            'encoded_credential' => Base64.encode64(mock_user_one) },
        'vetsgovuser228' => { 'credential_payload' => JSON.parse(mock_user_two_two_eight),
                              'encoded_credential' => Base64.encode64(mock_user_two_two_eight) } }
    end

    before { allow(Settings.sign_in).to receive(:mock_credential_dir).and_return(vets_api_mockdata_stub) }

    it 'creates a mocked_data hash with payloads from read files' do
      read_data = subject
      read_data.each do |user_identifier, payload|
        expected_data = expected_mock_data[user_identifier]

        expect(payload[:encoded_credential]).to eq(expected_data['encoded_credential'])
        expect(payload[:credential_payload]).to eq(expected_data['credential_payload'])
      end
    end
  end
end
