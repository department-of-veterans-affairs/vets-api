# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/vba_document_fixtures'
require 'vba_documents/upload_processor'

RSpec.describe VBADocuments::UploadProcessor, type: :job do
  include VBADocuments::Fixtures

  let(:client_stub) { instance_double('PensionBurial::Service') }
  let(:faraday_response) { instance_double('Faraday::Rresponse') }
  let(:valid_metadata) { get_fixture('valid_metadata.json').read }
  let(:invalid_metadata_missing) { get_fixture('invalid_metadata_missing.json').read }
  let(:invalid_metadata_nonstring) { get_fixture('invalid_metadata_nonstring.json').read }

  let(:valid_doc) { get_fixture('valid_doc.pdf') }
  let(:non_pdf_doc) { get_fixture('valid_metadata.json') }

  let(:valid_parts) do
    { 'metadata' => valid_metadata,
      'document' => valid_doc }
  end

  let(:valid_parts_attachment) do
    { 'metadata' => valid_metadata,
      'document' => valid_doc,
      'attachment1' => valid_doc }
  end

  let(:invalid_parts_missing) do
    { 'metadata' => invalid_metadata_missing,
      'document' => valid_doc }
  end

  let(:invalid_parts_nonstring) do
    { 'metadata' => invalid_metadata_nonstring,
      'document' => valid_doc }
  end

  before(:each) do
    s3_client = instance_double(Aws::S3::Resource)
    allow(Aws::S3::Resource).to receive(:new).and_return(s3_client)
    @s3_bucket = instance_double(Aws::S3::Bucket)
    @s3_object = instance_double(Aws::S3::Object)
    allow(s3_client).to receive(:bucket).and_return(@s3_bucket)
    allow(@s3_bucket).to receive(:object).and_return(@s3_object)
  end

  describe '#perform' do
    let(:upload) { FactoryBot.create(:upload_submission) }

    it 'parses and uploads a valid multipart payload' do
      allow(@s3_object).to receive(:download_file)
      allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts }
      allow(PensionBurial::Service).to receive(:new) { client_stub }
      allow(faraday_response).to receive(:status).and_return(200)
      allow(faraday_response).to receive(:body).and_return('')
      allow(faraday_response).to receive(:success?).and_return(true)
      capture_body = nil
      expect(client_stub).to receive(:upload) { |arg|
        capture_body = arg
        faraday_response
      }
      described_class.new.perform(upload.guid)
      expect(capture_body).to be_a(Hash)
      expect(capture_body).to have_key('metadata')
      expect(capture_body).to have_key('document')
      metadata = JSON.parse(capture_body['metadata'])
      expect(metadata['uuid']).to eq(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('received')
    end

    it 'parses and uploads a valid multipart payload with attachments' do
      allow(@s3_object).to receive(:download_file)
      allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts_attachment }
      allow(PensionBurial::Service).to receive(:new) { client_stub }
      allow(faraday_response).to receive(:status).and_return(200)
      allow(faraday_response).to receive(:body).and_return('')
      allow(faraday_response).to receive(:success?).and_return(true)
      capture_body = nil
      expect(client_stub).to receive(:upload) { |arg|
        capture_body = arg
        faraday_response
      }
      described_class.new.perform(upload.guid)
      expect(capture_body).to be_a(Hash)
      expect(capture_body).to have_key('metadata')
      expect(capture_body).to have_key('document')
      expect(capture_body).to have_key('attachment1')
      metadata = JSON.parse(capture_body['metadata'])
      expect(metadata['uuid']).to eq(upload.guid)
      expect(metadata['numberAttachments']).to eq(1)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('received')
    end

    it 'sets error status for invalid multipart format' do
      allow(@s3_object).to receive(:download_file)
      allow(VBADocuments::MultipartParser).to receive(:parse)
        .and_raise(VBADocuments::UploadError.new(code: 'DOC101'))
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC101')
    end

    it 'sets error status for non-JSON metadata part' do
      allow(@s3_object).to receive(:download_file)
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => valid_doc, 'document' => valid_doc }
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
    end

    it 'sets error status for unparseable JSON metadata part' do
      allow(@s3_object).to receive(:download_file)
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => 'I am not JSON', 'document' => valid_doc }
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
    end

    it 'sets error status for non-PDF document parts' do
      allow(@s3_object).to receive(:download_file)
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => valid_metadata, 'document' => valid_metadata }
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC103')
    end

    it 'sets error status for unparseable PDF document parts' do
      allow(@s3_object).to receive(:download_file)
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => valid_metadata, 'document' => non_pdf_doc }
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC103')
    end

    it 'sets error status for missing JSON metadata' do
      allow(@s3_object).to receive(:download_file)
      allow(VBADocuments::MultipartParser).to receive(:parse) { invalid_parts_missing }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
    end

    it 'sets error status for out-of-spec JSON metadata' do
      allow(@s3_object).to receive(:download_file)
      allow(VBADocuments::MultipartParser).to receive(:parse) { invalid_parts_nonstring }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
    end

    it 'sets error status for missing metadata part' do
      allow(@s3_object).to receive(:download_file)
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'document' => valid_doc }
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
    end

    it 'sets error status for missing document part' do
      allow(@s3_object).to receive(:download_file)
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => valid_metadata }
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC103')
    end

    xit 'sets error status for non-PDF attachment parts' do
    end

    xit 'sets error status for unexpected attachment part names' do
    end

    it 'sets error status for downstream server error' do
      allow(@s3_object).to receive(:download_file)
      allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts }
      allow(PensionBurial::Service).to receive(:new) { client_stub }
      allow(faraday_response).to receive(:status).and_return(422)
      allow(faraday_response).to receive(:body).and_return('')
      allow(faraday_response).to receive(:success?).and_return(false)
      capture_body = nil
      expect(client_stub).to receive(:upload) { |arg|
        capture_body = arg
        faraday_response
      }
      described_class.new.perform(upload.guid)
      expect(capture_body).to be_a(Hash)
      expect(capture_body).to have_key('metadata')
      expect(capture_body).to have_key('document')
      metadata = JSON.parse(capture_body['metadata'])
      expect(metadata['uuid']).to eq(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC104')
    end

    it 'sets error status for downstream server error' do
      allow(@s3_object).to receive(:download_file)
      allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts }
      allow(PensionBurial::Service).to receive(:new) { client_stub }
      allow(faraday_response).to receive(:status).and_return(500)
      allow(faraday_response).to receive(:body).and_return('')
      allow(faraday_response).to receive(:success?).and_return(false)
      capture_body = nil
      expect(client_stub).to receive(:upload) { |arg|
        capture_body = arg
        faraday_response
      }
      described_class.new.perform(upload.guid)
      expect(capture_body).to be_a(Hash)
      expect(capture_body).to have_key('metadata')
      expect(capture_body).to have_key('document')
      metadata = JSON.parse(capture_body['metadata'])
      expect(metadata['uuid']).to eq(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC201')
    end
  end
end
