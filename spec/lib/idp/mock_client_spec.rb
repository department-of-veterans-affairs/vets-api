# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('lib', 'idp', 'mock_client')

RSpec.describe Idp::MockClient do
  subject(:client) { described_class.new }

  describe '#intake' do
    it 'returns id, bucket, and pdf_key' do
      result = client.intake(file_name: 'test.pdf', pdf_base64: Base64.encode64('fake pdf content'))

      expect(result).to include('id', 'bucket', 'pdf_key')
      expect(result['bucket']).to eq('local-idp')
    end
  end

  describe '#status' do
    it 'returns status for an ingested document' do
      contract = client.intake(file_name: 'test.pdf', pdf_base64: Base64.encode64('fake pdf content'))
      result = client.status(contract['id'])

      expect(result['scan_status']).to eq('completed')
      expect(result['file_name']).to eq('test.pdf')
    end

    it 'raises an error for an unknown document' do
      expect { client.status('nonexistent-id') }.to raise_error(Idp::Error, /not found/)
    end
  end

  describe '#output' do
    it 'returns artifact forms for an ingested document' do
      contract = client.intake(file_name: 'test.pdf', pdf_base64: Base64.encode64('fake pdf content'))
      result = client.output(contract['id'], type: 'artifact')

      expect(result['forms']).to be_an(Array)
      expect(result['forms'].map { |f| f['artifactType'] }).to include('DD214', 'DEATH')
    end
  end

  describe '#download' do
    it 'returns artifact data by kvpid' do
      contract = client.intake(file_name: 'test.pdf', pdf_base64: Base64.encode64('fake pdf content'))
      forms = client.output(contract['id'], type: 'artifact')['forms']
      kvpid = forms.first['mmsArtifactValidationId']

      result = client.download(contract['id'], kvpid:)

      expect(result).to include('FIRST_NAME', 'LAST_NAME')
    end

    it 'raises an error for an unknown kvpid' do
      contract = client.intake(file_name: 'test.pdf', pdf_base64: Base64.encode64('fake pdf content'))

      expect { client.download(contract['id'], kvpid: 'bad-kvp') }
        .to raise_error(Idp::Error, /not found/)
    end
  end
end
