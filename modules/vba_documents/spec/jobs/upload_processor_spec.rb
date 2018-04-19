#frozen_string_literal: true

require 'rails_helper'
require_relative '../support/vba_document_fixtures'

RSpec.describe VBADocuments::UploadProcessor, type: :job do
  include VBADocuments::Fixtures

  let(:client_stub) { instance_double('PensionBurial::Service') }
  let(:faraday_response) { instance_double('Faraday::Rresponse') }
  let(:valid_metadata) { get_fixture('valid_metadata.json').read }
  let(:valid_doc) { get_fixture('valid_doc.pdf') }

  let(:valid_parts) {
    { 'metadata' => valid_metadata,
      'document' => valid_doc
    }
  }

  before(:each) do
     s3_client = instance_double(Aws::S3::Resource)
     allow(Aws::S3::Resource).to receive(:new).and_return(s3_client)
     @s3_bucket = instance_double(Aws::S3::Bucket)
     @s3_object = instance_double(Aws::S3::Object)
     allow(s3_client).to receive(:bucket).and_return(@s3_bucket)
     allow(@s3_bucket).to receive(:object).and_return(@s3_object)
  end

  describe '#perform' do
    let (:upload) { FactoryBot.create(:upload_submission) }

    it 'parses and uploads a valid multipart payload' do
      allow(@s3_object).to receive(:download_file)
      allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts }
      allow(PensionBurial::Service).to receive(:new) { client_stub }
      allow(faraday_response).to receive(:status).and_return(200)
      allow(faraday_response).to receive(:body).and_return('')
      allow(faraday_response).to receive(:success?).and_return(true)
      capture_body = nil
      expect(client_stub).to receive(:upload) { |arg| capture_body = arg; faraday_response }
      described_class.new.perform(upload.guid)
      expect(capture_body).to be_a(Hash)
      expect(capture_body).to have_key('metadata')
      expect(capture_body).to have_key('document')
      metadata = JSON.parse(capture_body['metadata'])
      expect(metadata['uuid']).to eq(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('received')
    end

    it 'sets error status for invalid multipart format' do
    end

    it 'sets error status for non-JSON metadata part' do
    end

    it 'sets error status for non-PDF document parts' do
    end

    it 'sets error status for non-PDF attachment parts' do
    end

    it 'sets error status for invalid JSON metadata' do
    end

    it 'sets error status for missing document part' do
    end

    it 'sets error status for unexpected attachment part names' do
    end

    it 'sets error status for downstream error' do

    end
  end

end
