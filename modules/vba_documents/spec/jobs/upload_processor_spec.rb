# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/vba_document_fixtures'

RSpec.describe VBADocuments::UploadProcessor, type: :job do
  include VBADocuments::Fixtures

  let(:client_stub) { instance_double('CentralMail::Service') }
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:valid_metadata) { get_fixture('valid_metadata.json').read }
  let(:invalid_metadata_missing) { get_fixture('invalid_metadata_missing.json').read }
  let(:invalid_metadata_nonstring) { get_fixture('invalid_metadata_nonstring.json').read }

  let(:valid_doc) { get_fixture('valid_doc.pdf') }
  let(:locked_doc) { get_fixture('locked.pdf') }
  let(:non_pdf_doc) { get_fixture('valid_metadata.json') }

  let(:valid_parts) do
    { 'metadata' => valid_metadata,
      'content' => valid_doc }
  end

  let(:valid_parts_but_locked) do
    { 'metadata' => valid_metadata,
      'content' => locked_doc }
  end

  let(:valid_parts_attachment) do
    { 'metadata' => valid_metadata,
      'content' => valid_doc,
      'attachment1' => valid_doc }
  end

  let(:valid_parts_locked_attachment) do
    { 'metadata' => valid_metadata,
      'content' => valid_doc,
      'attachment1' => locked_doc }
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

    context 'with pdf size too large' do
      { 'sets error status for file content size exceeding 100MB' => :valid_parts,
        'sets error for file part size exceeding 100MB' => :valid_parts_attachment }.each_pair do |_k, v|
        it 'sets error for file part size exceeding 100MB' do
          allow(VBADocuments::MultipartParser).to receive(:parse) { send v }
          allow(File).to receive(:size) do
            r_val = 100_000_001
            if Thread.current[:checking_attachment] && v.eql?(:valid_parts_attachment)
              r_val = 100_000_001
            elsif v.eql?(:valid_parts_attachment)
              r_val = 1
            end
            r_val
          end
          described_class.new.perform(upload.guid)
          updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
          expect(updated.status).to eq('error')
          expect(updated.code).to eq('DOC106')
        end
      end
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
      expect(updated.detail).to eq('Incorrect content-type for metadata part')
    end

    it 'sets error status for unparseable JSON metadata part' do
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => 'I am not JSON', 'content' => valid_doc }
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
      expect(updated.detail).to eq('Invalid JSON object')
    end

    it 'sets error status for parsable JSON metadata but not an object' do
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => [valid_metadata].to_json, 'content' => valid_doc }
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
      expect(updated.detail).to eq('Invalid JSON object')
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
      expect(updated.detail).to eq('Non-numeric or invalid-length fileNumber')
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
      expect(updated.detail).to eq('Non-numeric or invalid-length fileNumber')
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
      expect(updated.detail).to eq('Non-numeric or invalid-length fileNumber')
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
      expect(updated.detail).to eq('Non-numeric or invalid-length fileNumber')
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

    CentralMail::Utilities::REQUIRED_KEYS.each do |key|
      it "sets error status for missing JSON metadata #{key}" do
        allow(VBADocuments::MultipartParser).to receive(:parse) {
          v = valid_parts
          hash = JSON.parse(v['metadata'])
          hash.delete(key)
          v['metadata'] = hash.to_json
          v
        }
        described_class.new.perform(upload.guid)
        updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
        expect(updated.status).to eq('error')
        expect(updated.code).to eq('DOC102')
        expect(updated.detail).to eq("Missing required keys: #{key}")
      end
    end

    context 'with locked pdf' do
      { 'sets error status for locked pdf attachment' => [:valid_parts_locked_attachment,
                                                          'Invalid PDF content, part attachment1'],
        'sets error status for locked pdf' => [:valid_parts_but_locked, 'Invalid PDF content, part content'] }
        .each_pair do |k, v|
        it k do
          allow(VBADocuments::MultipartParser).to receive(:parse) { send v.first }
          described_class.new.perform(upload.guid)
          updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
          expect(updated.status).to eq('error')
          expect(updated.code).to eq('DOC103')
          expect(updated.detail).to eq(v.last)
        end
      end
    end

    it 'sets error status for out-of-spec JSON metadata' do
      allow(VBADocuments::MultipartParser).to receive(:parse) { invalid_parts_nonstring }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
      expect(updated.detail).to eq('Non-string values for keys: fileNumber')
    end

    it 'sets error status for missing metadata part' do
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'content' => valid_doc }
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
      expect(updated.detail).to eq('No metadata part present')
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

    it 'sets uploaded pdf data' do
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        file = 'modules/vba_documents/spec/fixtures/valid_multipart_pdf_attachments.blob'
        VBADocuments::MultipartParser.parse_file(file)
      }
      described_class.new.perform(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      pdf_data = updated.uploaded_pdf
      expect(pdf_data).to be_a(Hash)
      expect(pdf_data).to have_key('doc_type')
      expect(pdf_data).to have_key('total_documents')
      expect(pdf_data).to have_key('total_pages')
      expect(pdf_data).to have_key('content')
      content = pdf_data['content']
      expect(content).to have_key('page_count')
      expect(content).to have_key('dimensions')
      expect(content).to have_key('attachments')
    end

    xit 'sets error status for non-PDF attachment parts' do
    end

    xit 'sets error status for unexpected attachment part names' do
    end

    it 'sets error status for upstream zip code validation' do
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
      expect(updated.detail).to eq('Upstream status: 412 - Missing ZIP Code. ' \
                                   'ZIP Code must be 5 digits, or 9 digits in XXXXX-XXXX format. ' \
                                   'Specify \'00000\' for non-US addresses.')
    end

    it 'sets error status for upstream server error' do
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

    it 'checks for updated status for Gateway timeout error' do
      allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts }
      allow(CentralMail::Service).to receive(:new) { client_stub }
      expect(client_stub).to receive(:upload)
        .and_raise(Common::Exceptions::GatewayTimeout.new)
      expect { described_class.new.perform(upload.guid) }.not_to raise_error(Common::Exceptions::GatewayTimeout)
      upload.reload
      expect(upload.status).to eq('uploaded')
    end

    it 'checks for updated status for Faraday timeout error' do
      allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts }
      allow(CentralMail::Service).to receive(:new) { client_stub }
      expect(client_stub).to receive(:upload)
        .and_raise(Faraday::TimeoutError.new)
      expect { described_class.new.perform(upload.guid) }.not_to raise_error(Faraday::TimeoutError)
      upload.reload
      expect(upload.status).to eq('uploaded')
    end
  end
end
