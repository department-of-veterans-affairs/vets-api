# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/vba_document_fixtures'
require 'vba_documents/multipart_parser'
require 'vba_documents/pdf_inspector'

RSpec.describe VBADocuments::UploadProcessor, type: :job do
  include VBADocuments::Fixtures

  let(:test_caller) { { 'caller' => 'tester' } }
  let(:client_stub) { instance_double('CentralMail::Service') }
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:valid_metadata) { get_fixture('valid_metadata.json').read }
  let(:missing_first) { get_fixture('missing_first_metadata.json').read }
  let(:missing_last) { get_fixture('missing_last_metadata.json').read }
  let(:bad_with_digits_first) { get_fixture('bad_with_digits_first_metadata.json').read }
  let(:bad_with_funky_characters_last) { get_fixture('bad_with_funky_characters_last_metadata.json').read }
  let(:dashes_slashes_first_last) { get_fixture('dashes_slashes_first_last_metadata.json').read }
  let(:name_too_long_metadata) { get_erbed_fixture('name_too_long_metadata.json.erb').read }
  let(:invalid_metadata_missing) { get_fixture('invalid_metadata_missing.json').read }
  let(:invalid_metadata_missing_lob) { get_fixture('invalid_metadata_missing_LOB.json').read }
  let(:invalid_metadata_unknown_lob) { get_fixture('invalid_metadata_unknown_LOB.json').read }
  let(:invalid_metadata_nonstring) { get_fixture('invalid_metadata_nonstring.json').read }
  let(:valid_metadata_space_in_name) { get_fixture('valid_metadata_space_in_name.json').read }
  let(:valid_doc) { get_fixture('valid_doc.pdf') }
  let(:locked_doc) { get_fixture('locked.pdf') }
  let(:non_pdf_doc) { get_fixture('valid_metadata.json') }

  let(:valid_parts) do
    {
      'metadata' => valid_metadata,
      'content' => valid_doc
    }
  end

  let(:valid_parts_but_locked) do
    {
      'metadata' => valid_metadata,
      'content' => locked_doc
    }
  end

  let(:valid_parts_attachment) do
    {
      'metadata' => valid_metadata,
      'content' => valid_doc,
      'attachment1' => valid_doc
    }
  end

  let(:valid_parts_locked_attachment) do
    {
      'metadata' => valid_metadata,
      'content' => valid_doc,
      'attachment1' => locked_doc
    }
  end

  let(:invalid_parts_missing) do
    {
      'metadata' => invalid_metadata_missing,
      'content' => valid_doc
    }
  end

  let(:invalid_parts_nonstring) do
    {
      'metadata' => invalid_metadata_nonstring,
      'content' => valid_doc
    }
  end

  before do
    allow_any_instance_of(described_class).to receive(:cancelled?).and_return(false)
    allow_any_instance_of(Tempfile).to receive(:size).and_return(1) # must be > 0 or submission will error w/DOC107
    objstore = instance_double(VBADocuments::ObjectStore)
    version = instance_double(Aws::S3::ObjectVersion)
    bucket = instance_double(Aws::S3::Bucket)
    obj = instance_double(Aws::S3::Object)
    allow(VBADocuments::ObjectStore).to receive(:new).and_return(objstore)
    allow(objstore).to receive(:first_version).and_return(version)
    allow(objstore).to receive(:download)
    allow(objstore).to receive(:bucket).and_return(bucket)
    allow(bucket).to receive(:object).and_return(obj)
    allow(obj).to receive(:exists?).and_return(true)
    allow(version).to receive(:last_modified).and_return(DateTime.now.utc)
  end

  describe '#perform' do
    let(:upload) { FactoryBot.create(:upload_submission, :status_uploaded, consumer_name: 'test consumer') }
    let(:v2_upload) { FactoryBot.create(:upload_submission, :status_uploaded, :version_2) }

    context 'duplicates' do
      before(:context) do
        @transaction_state = use_transactional_tests
        # need all subprocesses to see the state of the DB.  Transactional isolation will hurt us here.
        self.use_transactional_tests = false
        @upload_model = VBADocuments::UploadSubmission.new
        @upload_model.status = 'uploaded'
        @upload_model.save!
      end

      after(:context) do
        self.use_transactional_tests = @transaction_state
        @upload_model.delete
      end

      # Put in as a response to https://vajira.max.gov/browse/API-6651
      it 'does not send duplicates if called multiple times concurrently on the same guid' do
        allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts_attachment }
        allow(CentralMail::Service).to receive(:new) { client_stub }
        allow(faraday_response).to receive(:status).and_return(200)
        allow(faraday_response).to receive(:body).and_return('')
        allow(faraday_response).to receive(:success?).and_return(true)
        allow(client_stub).to receive(:upload).and_return(faraday_response)
        num_times = 7
        # Why 7?  That's the most times a duplicate ever occurred.  See the excel spreadsheet in the ticket!
        temp_files = []
        num_times.times do
          temp_files << Tempfile.new
        end
        pids = []
        num_times.times do |i|
          # Why fork instead of threads?  We are testing the advisory lock under different processes just as sidekiq
          # will run the jobs.
          pids << fork do
            response = described_class.new.perform(@upload_model.guid, test_caller)
            writing = response.to_s
            temp_files[i].write(writing)
            temp_files[i].close
          end
        end
        pids.each { |pid| Process.waitpid(pid) } # wait for my children to complete
        responses = []
        temp_files.each do |tf|
          responses << File.open(tf.path, &:read)
        end
        expect(responses.select { |e| e.eql?('true') }.length).to eq(1)
        expect(responses.select { |e| e.eql?('false') }.length).to eq(num_times - 1)
      end
    end

    it 'tracks how we got into the recieved state' do
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
      described_class.new.perform(upload.guid, test_caller)
      upload.reload
      expect(upload.metadata['status']['received']['cause'].first).to eq('tester')
    end

    it 'counts concurrent duplicates, and tracks causes, that our upstream provider asserts occurred' do
      upload_model = VBADocuments::UploadSubmission.new
      upload_model.status = 'uploaded'
      upload_model.save!
      allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts_attachment }
      allow(CentralMail::Service).to receive(:new) { client_stub }
      allow(faraday_response).to receive(:status).and_return(429)
      allow(faraday_response).to receive(:body).and_return("UUID already in cache [uuid: #{upload_model.guid}]")
      allow(faraday_response).to receive(:success?).and_return(false)
      allow(client_stub).to receive(:upload).and_return(faraday_response)
      allow(File).to receive(:size).and_return(10)
      allow_any_instance_of(File).to receive(:rewind).and_return(nil)
      other_caller = { 'caller' => 'tester2' }
      response = described_class.new.perform(upload_model.guid, test_caller)
      expect(response).to be(false)
      described_class.new.perform(upload_model.guid, test_caller)
      described_class.new.perform(upload_model.guid, test_caller)
      upload_model.reload
      expect(upload_model.metadata['uuid_already_in_cache_count']).to eq(3)
      expect(upload_model.metadata['status']['uploaded']['uuid_already_in_cache_cause']['tester'].count).to eq(3)
      described_class.new.perform(upload_model.guid, other_caller)
      upload_model.reload
      expect(upload_model.metadata['status']['uploaded']['uuid_already_in_cache_cause']['tester2'].count).to eq(1)
    end

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
      described_class.new.perform(upload.guid, test_caller)
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
      described_class.new.perform(upload.guid, test_caller)
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

    context 'when payload is empty' do
      let(:empty_payload) { get_fixture('emptyfile.blob') }

      before do
        allow(VBADocuments::PayloadManager).to receive(:download_raw_file).and_return([empty_payload, DateTime.now])
      end

      it 'sets error status with DOC107: Empty payload' do
        described_class.new.perform(upload.guid, test_caller)
        upload.reload
        expect(upload.status).to eq('error')
        expect(upload.code).to eq('DOC107')
        expect(upload.detail).to eq('Empty payload')
      end
    end

    context 'with pdf size too large' do
      { 'sets error status for file content size exceeding 100MB' => :valid_parts,
        'sets error for file part size exceeding 100MB' => :valid_parts_attachment }.each_pair do |_k, v|
        it 'sets error for file part size exceeding 100MB' do
          allow(VBADocuments::MultipartParser).to receive(:parse) { send v }
          allow(File).to receive(:size).and_return(100_000_001)

          described_class.new.perform(upload.guid, test_caller)
          updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
          expect(updated.status).to eq('error')
          expect(updated.code).to eq('DOC106')
        end
      end
    end

    it 'sets error status for invalid multipart format' do
      allow(VBADocuments::MultipartParser).to receive(:parse)
        .and_raise(VBADocuments::UploadError.new(code: 'DOC101'))
      described_class.new.perform(upload.guid, test_caller)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC101')
    end

    %i[missing_first missing_last bad_with_digits_first bad_with_funky_characters_last
       name_too_long_metadata].each do |bad|
      it "sets error status for #{bad} name" do
        allow(VBADocuments::MultipartParser).to receive(:parse) {
          { 'metadata' => send(bad), 'content' => valid_doc }
        }
        described_class.new.perform(upload.guid, test_caller)
        updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
        expect(updated.status).to eq('error')
        expect(updated.code).to eq('DOC102')
        expect(updated.detail).to match(/^Invalid Veteran name/)
      end
    end

    %i[dashes_slashes_first_last valid_metadata_space_in_name].each do |allowed|
      it "allows #{allowed} names" do
        allow(VBADocuments::MultipartParser).to receive(:parse) {
          { 'metadata' => send(allowed), 'content' => valid_doc }
        }
        allow(CentralMail::Service).to receive(:new) { client_stub }
        allow(faraday_response).to receive(:status).and_return(200)
        allow(faraday_response).to receive(:body).and_return('')
        allow(faraday_response).to receive(:success?).and_return(true)
        expect(client_stub).to receive(:upload) { faraday_response }
        described_class.new.perform(upload.guid, test_caller)
        updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
        expect(updated.status).to eq('received')
      end
    end

    it 'sets error status for non-JSON metadata part' do
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => valid_doc, 'content' => valid_doc }
      }
      described_class.new.perform(upload.guid, test_caller)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
      expect(updated.detail).to eq('Incorrect content-type for metadata part')
    end

    it 'sets error status for unparseable JSON metadata part' do
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => 'I am not JSON', 'content' => valid_doc }
      }
      described_class.new.perform(upload.guid, test_caller)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
      expect(updated.detail).to eq('Invalid JSON object')
    end

    it 'sets error status for parsable JSON metadata but not an object' do
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => [valid_metadata].to_json, 'content' => valid_doc }
      }
      described_class.new.perform(upload.guid, test_caller)
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
      described_class.new.perform(upload.guid, test_caller)
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
      described_class.new.perform(upload.guid, test_caller)
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
      described_class.new.perform(upload.guid, test_caller)
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
      described_class.new.perform(upload.guid, test_caller)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
      expect(updated.detail).to eq('Non-numeric or invalid-length fileNumber')
    end

    it 'sets error status for non-PDF document parts' do
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => valid_metadata, 'content' => valid_metadata }
      }
      described_class.new.perform(upload.guid, test_caller)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC103')
    end

    it 'sets error status for unparseable PDF document parts' do
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => valid_metadata, 'content' => non_pdf_doc }
      }
      described_class.new.perform(upload.guid, test_caller)
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
        described_class.new.perform(upload.guid, test_caller)
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
          described_class.new.perform(upload.guid, test_caller)
          updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
          expect(updated.status).to eq('error')
          expect(updated.code).to eq('DOC103')
          expect(updated.detail).to eq(v.last)
        end
      end
    end

    it 'sets error status for out-of-spec JSON metadata' do
      allow(VBADocuments::MultipartParser).to receive(:parse) { invalid_parts_nonstring }
      described_class.new.perform(upload.guid, test_caller)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
      expect(updated.detail).to eq('Non-string values for keys: fileNumber')
    end

    it 'sets error status for missing metadata part' do
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'content' => valid_doc }
      }
      described_class.new.perform(upload.guid, test_caller)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
      expect(updated.detail).to eq('No metadata part present')
    end

    it 'sets error status for missing document part' do
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => valid_metadata }
      }
      described_class.new.perform(upload.guid, test_caller)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC103')
    end

    it 'sets document size metadata' do
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'content' => valid_doc }
      }
      described_class.new.perform(upload.guid, test_caller)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.metadata['size'].class).to be == Integer
    end

    context 'document is base64 encoded' do
      it 'sets document base64_encoded metadata to true' do
        allow(VBADocuments::MultipartParser).to receive(:base64_encoded?).and_return(true)
        allow(VBADocuments::MultipartParser).to receive(:parse) {
          { 'content' => valid_doc }
        }
        described_class.new.perform(upload.guid, test_caller)
        upload.reload
        expect(upload.metadata['base64_encoded']).to be(true)
      end
    end

    context 'document is not base64 encoded' do
      it 'sets document base64_encoded metadata to false' do
        allow(VBADocuments::MultipartParser).to receive(:base64_encoded?).and_return(false)
        allow(VBADocuments::MultipartParser).to receive(:parse) {
          { 'content' => valid_doc }
        }
        described_class.new.perform(upload.guid, test_caller)
        upload.reload
        expect(upload.metadata['base64_encoded']).to be(false)
      end
    end

    it 'saves the SHA-256 checksum to the submission metadata' do
      allow(VBADocuments::MultipartParser).to receive(:parse) { { 'content' => valid_doc } }
      sha256_char_length = 64
      described_class.new.perform(upload.guid, test_caller)
      upload.reload
      expect(upload.metadata['sha256_checksum']).to be_a(String)
      expect(upload.metadata['sha256_checksum'].length).to eq(sha256_char_length)
    end

    it 'saves the MD5 checksum to the submission metadata' do
      allow(VBADocuments::MultipartParser).to receive(:parse) { { 'content' => valid_doc } }
      md5_char_length = 32
      described_class.new.perform(upload.guid, test_caller)
      upload.reload
      expect(upload.metadata['md5_checksum']).to be_a(String)
      expect(upload.metadata['md5_checksum'].length).to eq(md5_char_length)
    end

    context 'with invalid sizes' do
      %w[10x102 79x10].each do |invalid_size|
        it "sets an error status for invalid size of #{invalid_size}" do
          allow(VBADocuments::MultipartParser).to receive(:parse) {
            { 'metadata' => valid_metadata, 'content' => get_fixture("#{invalid_size}.pdf") }
          }
          described_class.new.perform(upload.guid, test_caller)
          updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
          expect(updated.status).to eq('error')
          expect(updated.code).to eq('DOC108')
        end
      end

      context 'when metadata.json contains skipDimensionCheck = true' do
        let(:special_metadata) { JSON.parse(valid_metadata).merge({ 'skipDimensionCheck' => true }).to_json }
        let(:content) { get_fixture('10x102.pdf') }

        before do
          allow(CentralMail::Service).to receive(:new) { client_stub }
          allow(faraday_response).to receive(:status).and_return(200)
          allow(faraday_response).to receive(:body).and_return('')
          allow(faraday_response).to receive(:success?).and_return(true)
          allow(client_stub).to receive(:upload).and_return(faraday_response)
        end

        it 'allows the upload' do
          allow(VBADocuments::MultipartParser).to receive(:parse) do
            { 'metadata' => special_metadata, 'content' => content }
          end
          described_class.new.perform(upload.guid, test_caller)
          updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
          expect(updated.uploaded_pdf.dig('content', 'dimensions', 'oversized_pdf')).to eq(true)
          expect(updated.status).to eq('received')
        end
      end
    end

    it 'sets uploaded pdf data' do
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        file = 'modules/vba_documents/spec/fixtures/valid_multipart_pdf_attachments_invalid_metadata.blob'
        VBADocuments::MultipartParser.parse_file(file)
      }
      described_class.new.perform(upload.guid, test_caller)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      pdf_data = updated.uploaded_pdf
      expect(pdf_data).to be_a(Hash)
      expect(pdf_data).to have_key('total_documents')
      expect(pdf_data).to have_key('total_pages')
      expect(pdf_data).to have_key('content')
      content = pdf_data['content']
      attachment = pdf_data.dig('content', 'attachments').first
      %w[page_count dimensions file_size sha256_checksum].each do |metadata_key|
        expect(content).to have_key(metadata_key)
        expect(attachment).to have_key(metadata_key)
      end
    end

    context 'with valid line of business' do
      before do
        @md = JSON.parse(valid_metadata)
        allow(VBADocuments::MultipartParser).to receive(:parse) {
          { 'metadata' => @md.to_json, 'content' => valid_doc }
        }
        allow(CentralMail::Service).to receive(:new) { client_stub }
        allow(faraday_response).to receive(:status).and_return(200)
        allow(faraday_response).to receive(:body).and_return('')
        allow(faraday_response).to receive(:success?).and_return(true)
        capture_body = nil
        expect(client_stub).to receive(:upload) { |arg|
          capture_body = arg
          faraday_response
        }
      end

      it 'records line of business' do
        @md['businessLine'] = 'CMP'
        described_class.new.perform(upload.guid, test_caller)
        updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
        expect(updated.uploaded_pdf['line_of_business']).to eq('CMP')
      end

      it 'maps the future line of business OTH to CMP' do
        @md['businessLine'] = 'OTH'
        described_class.new.perform(upload.guid, test_caller)
        updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
        expect(updated.uploaded_pdf['line_of_business']).to eq('OTH')
        expect(updated.uploaded_pdf['submitted_line_of_business']).to eq('CMP')
      end
    end

    it 'sets error status and records invalid lines of business' do
      md = JSON.parse(invalid_metadata_unknown_lob)
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => md.to_json, 'content' => valid_doc }
      }
      described_class.new.perform(upload.guid, test_caller)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
      expect(updated.detail).to start_with('Invalid businessLine provided')
      expect(updated.detail).to match(/DROC/)
    end

    it 'sets error status and records missing lines of business for V2' do
      md = JSON.parse(invalid_metadata_missing_lob)
      allow(VBADocuments::MultipartParser).to receive(:parse) {
        { 'metadata' => md.to_json, 'content' => valid_doc }
      }
      allow(CentralMail::Service).to receive(:new) { client_stub }
      allow(faraday_response).to receive(:status).and_return(200)
      allow(faraday_response).to receive(:body).and_return('')
      allow(faraday_response).to receive(:success?).and_return(true)
      described_class.new.perform(v2_upload.guid, test_caller)
      updated = VBADocuments::UploadSubmission.find_by(guid: v2_upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC102')
      expect(updated.detail).to start_with('The businessLine metadata field is missing or empty.')
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
      described_class.new.perform(upload.guid, test_caller)
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
      described_class.new.perform(upload.guid, test_caller)
      expect(capture_body).to be_a(Hash)
      expect(capture_body).to have_key('metadata')
      expect(capture_body).to have_key('document')
      metadata = JSON.parse(capture_body['metadata'])
      expect(metadata['uuid']).to eq(upload.guid)
      updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
      expect(updated.status).to eq('error')
      expect(updated.code).to eq('DOC104')
    end

    context 'with a upstream error' do
      before do
        allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts }
        allow(CentralMail::Service).to receive(:new) { client_stub }
        allow(faraday_response).to receive(:status).and_return(500)
        allow(faraday_response).to receive(:body).and_return('')
        allow(faraday_response).to receive(:success?).and_return(false)
      end

      it 'does not set error status for upstream server error' do
        capture_body = nil
        expect(client_stub).to receive(:upload) { |arg|
          capture_body = arg
          faraday_response
        }
        described_class.new.perform(upload.guid, test_caller)
        expect(capture_body).to be_a(Hash)
        expect(capture_body).to have_key('metadata')
        expect(capture_body).to have_key('document')
        metadata = JSON.parse(capture_body['metadata'])
        expect(metadata['uuid']).to eq(upload.guid)
        updated = VBADocuments::UploadSubmission.find_by(guid: upload.guid)
        expect(updated.status).not_to eq('error')
        expect(updated.code).not_to eq('DOC201')
      end

      it 'sets error status for upstream server error after retries' do
        capture_body = nil
        after_retries = 4
        expect(client_stub).to receive(:upload) { |arg|
          capture_body = arg
          faraday_response
        }
        described_class.new.perform(upload.guid, test_caller, after_retries)
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
        described_class.new.perform(upload.guid, test_caller)
        expect(described_class.jobs.last['at']).to eq(30.minutes.from_now.to_f)
        Timecop.return
      end
    end

    context 'when a Common::Exceptions::GatewayTimeout occurs' do
      before do
        allow(VBADocuments::MultipartParser).to receive(:parse) { valid_parts }
        allow(CentralMail::Service).to receive(:new).and_return(client_stub)
        allow(client_stub).to receive(:upload).and_raise(Common::Exceptions::GatewayTimeout)
        allow_any_instance_of(VBADocuments::UploadSubmission).to receive(:hit_upload_timeout_limit?).and_return(false)
        allow(VBADocuments::UploadSubmission).to receive(:refresh_statuses!)
      end

      it 'calls "track_upload_timeout_error" on the upload' do
        expect_any_instance_of(VBADocuments::UploadSubmission).to receive(:track_upload_timeout_error)
        described_class.new.perform(upload.guid, test_caller)
      end

      context 'when the upload timeout limit has been hit' do
        before do
          allow_any_instance_of(VBADocuments::UploadSubmission).to receive(:hit_upload_timeout_limit?).and_return(true)
          described_class.new.perform(upload.guid, test_caller)
          upload.reload
        end

        it 'updates the upload\'s status to a timeout-specific error' do
          expect(upload.status).to eql('error')
          expect(upload.code).to eql('DOC104')
          expect(upload.detail).to eql('Request timed out uploading to upstream system')
        end
      end

      context 'when the upload timeout limit has not been hit' do
        before do
          allow_any_instance_of(VBADocuments::UploadSubmission).to receive(:hit_upload_timeout_limit?).and_return(false)
        end

        it 'does not update the upload\'s status' do
          expect(upload.status).to eql('uploaded')
          expect(upload.code).to be(nil)
          expect(upload.detail).to be(nil)
        end
      end

      it 'refreshes the upload\'s status' do
        expect(VBADocuments::UploadSubmission).to receive(:refresh_statuses!).with([upload])
        described_class.new.perform(upload.guid, test_caller)
      end
    end
  end
end
