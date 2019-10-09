# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/vba_document_fixtures'
require 'vba_documents/object_store'
require 'vba_documents/upload_processor'

RSpec.describe VBADocuments::UploadProcessor, type: :job do
  include VBADocuments::Fixtures

  let(:client_stub) { instance_double('CentralMail::Service') }
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:valid_metadata) { get_fixture('valid_metadata.json').read }
  let(:invalid_metadata_missing) { get_fixture('invalid_metadata_missing.json').read }
  let(:invalid_metadata_nonstring) { get_fixture('invalid_metadata_nonstring.json').read }

  let(:valid_doc) { get_fixture('valid_doc.pdf') }
  let(:non_pdf_doc) { get_fixture('valid_metadata.json') }

  let(:valid_parts) do
    { 'metadata' => valid_metadata,
      'content' => valid_doc }
  end

  let(:valid_parts_attachment) do
    { 'metadata' => valid_metadata,
      'content' => valid_doc,
      'attachment1' => valid_doc }
  end

  let(:invalid_parts_missing) do
    { 'metadata' => invalid_metadata_missing,
      'content' => valid_doc }
  end

  let(:invalid_parts_nonstring) do
    { 'metadata' => invalid_metadata_nonstring,
      'content' => valid_doc }
  end

  before do
    objstore = instance_double(VBADocuments::ObjectStore)
    version = instance_double(Aws::S3::ObjectVersion)
    allow(VBADocuments::ObjectStore).to receive(:new).and_return(objstore)
    allow(objstore).to receive(:first_version).and_return(version)
    allow(objstore).to receive(:download)
    allow(version).to receive(:last_modified).and_return(DateTime.now.utc)
  end

  describe '#perform' do
    let(:upload) { FactoryBot.create(:upload_submission, :status_uploaded, consumer_name: 'test consumer') }

    it 'parses and uploads a valid multipart payload' do
      allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts }
      allow(CentralMail::Service).to receive(:new) { client_stub }
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
      allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts_attachment }
      allow(CentralMail::Service).to receive(:new) { client_stub }
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
      expect(metadata['source']).to eq('test consumer via VA API')
      expect(metadata['numberAttachments']).to eq(1)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('received')
    end

    it 'sets error for file part size exceeding 100MB' do
      allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts_attachment }
      allow(File).to receive(:size).and_return(100_000_001)
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC106')
    end

    it 'sets error status for invalid multipart format' do
      allow(VBADocuments::MultipartParser).to receive(:parse)
        .and_raise(VBADocuments::UploadError.new(code: 'DOC101'))
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC101')
    end

    it 'sets error status for non-JSON metadata part' do
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => valid_doc, 'content' => valid_doc }
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
    end

    it 'sets error status for unparseable JSON metadata part' do
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => 'I am not JSON', 'content' => valid_doc }
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
    end

    it 'sets error status for too-short fileNumber metadata' do
      md = JSON.parse(valid_metadata)
      md['fileNumber'] = '123456'
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => md.to_json, 'content' => valid_doc }
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
    end

    it 'sets error status for too-long fileNumber metadata' do
      md = JSON.parse(valid_metadata)
      md['fileNumber'] = '1234567890'
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => md.to_json, 'content' => valid_doc }
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
    end

    it 'sets error status for non-numeric fileNumber metadata' do
      md = JSON.parse(valid_metadata)
      md['fileNumber'] = 'c12345678'
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => md.to_json, 'content' => valid_doc }
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
    end

    it 'sets error status for dashes in fileNumber metadata' do
      md = JSON.parse(valid_metadata)
      md['fileNumber'] = '123-45-6789'
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => md.to_json, 'content' => valid_doc }
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
    end

    it 'sets error status for non-PDF document parts' do
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => valid_metadata, 'content' => valid_metadata }
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC103')
    end

    it 'sets error status for unparseable PDF document parts' do
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => valid_metadata, 'content' => non_pdf_doc }
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC103')
    end

    it 'sets error status for missing JSON metadata' do
      allow(VBADocuments::MultipartParser).to receive(:parse) { invalid_parts_missing }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
    end

    it 'sets error status for out-of-spec JSON metadata' do
      allow(VBADocuments::MultipartParser).to receive(:parse) { invalid_parts_nonstring }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
    end

    it 'sets error status for missing metadata part' do
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'content' => valid_doc }
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
    end

    it 'sets error status for missing document part' do
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => valid_metadata }
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC103')
    end

    context 'with invalid sizes' do
      %w[21x21 18x22 22x18].each do |invalid_size|
        it 'sets an error status for invalid size' do
          allow(VBADocuments::MultipartParser).to receive(:parse) {
            { 'metadata' => valid_metadata, 'content' => get_fixture("#{invalid_size}.pdf") }
          }
          described_class.new.perform(upload.guid)
          updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
          expect(updated.status).to eq('error')
          expect(updated.code).to eq('DOC108')
        end
      end
    end

    xit 'sets error status for non-PDF attachment parts' do
    end

    xit 'sets error status for unexpected attachment part names' do
    end

    it 'sets error status for downstream zip code validation' do
      allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts }
      allow(CentralMail::Service).to receive(:new) { client_stub }
      allow(faraday_response).to receive(:status).and_return(412)
      allow(faraday_response).to receive(:body).and_return(
        "Metadata Field Error - Missing zipCode [uuid: #{upload.guid}] "
      )
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
      expect(updated.detail).to eq('Downstream status: 412 - Missing ZIP Code. ' \
                                   'ZIP Code must be 5 digits, or 9 digits in XXXXX-XXXX format. ' \
                                   'Specify \'00000\' for non-US addresses.')
    end

    it 'sets error status for downstream server error' do
      allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts }
      allow(CentralMail::Service).to receive(:new) { client_stub }
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

    context 'with a downstream error' do
      before do
        allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts }
        allow(CentralMail::Service).to receive(:new) { client_stub }
        allow(faraday_response).to receive(:status).and_return(500)
        allow(faraday_response).to receive(:body).and_return('')
        allow(faraday_response).to receive(:success?).and_return(false)
      end

      it 'does not set error status for downstream server error' do
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
        expect(updated.status).not_to eq('error')
        expect(updated.code).not_to eq('DOC201')
      end

      it 'sets error status for downstream server error after retries' do
        capture_body = nil
        after_retries = 4
        expect(client_stub).to receive(:upload) { |arg|
          capture_body = arg
          faraday_response
        }
        described_class.new.perform(upload.guid, after_retries)
        expect(capture_body).to be_a(Hash)
        expect(capture_body).to have_key('metadata')
        expect(capture_body).to have_key('document')
        metadata = JSON.parse(capture_body['metadata'])
        expect(metadata['uuid']).to eq(upload.guid)
        updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
        expect(updated.status).to eq('error')
        expect(updated.code).to eq('DOC201')
      end

      it 'queues another job to retry the request' do
        expect(client_stub).to receive(:upload) { |_arg| faraday_response }
        Timecop.freeze(Time.zone.now)
        described_class.new.perform(upload.guid)
        expect(described_class.jobs.last['at']).to eq(30.minutes.from_now.to_f)
        Timecop.return
      end
    end

    it 'does not set error status for retriable timeout error' do
      allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts }
      allow(CentralMail::Service).to receive(:new) { client_stub }
      expect(client_stub).to receive(:upload)
        .and_raise(Faraday::TimeoutError.new)
      expect { described_class.new.perform(upload.guid) }.to raise_error(Faraday::TimeoutError)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('uploaded')
    end
  end
end
