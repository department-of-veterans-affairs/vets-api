# frozen_string_literal: true

require 'rails_helper'
require 'mockdata/writer'

describe MockedAuthentication::Mockdata::Writer do
  describe '.save_credential' do
    subject do
      MockedAuthentication::Mockdata::Writer.save_credential(credential:, credential_type:)
    end

    let(:credential) do
      {
        'email' => 'some_email!@email.com',
        'attributes' => 'some-attribute'
      }
    end
    let(:expected_email) { credential['email'].split('@')[0].tr('!', '') }
    let(:credential_type) { 'some-credential-type' }
    let(:expected_filename) do
      "#{Settings.sign_in.mock_credential_dir}/credentials/#{credential_type}/#{expected_email}.json"
    end
    let(:expected_payload) { JSON.pretty_generate(credential) }

    before { allow(File).to receive(:write) }

    it 'creates a file with expected filename and expected file payload' do
      expect(File).to receive(:write).with(expected_filename, expected_payload)
      subject
    end
  end
end
