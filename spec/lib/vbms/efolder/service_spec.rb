# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBMS::Efolder::Service do
  let(:metadata) {{
        'first_name' => 'Pat',
        'last_name' => 'Doe',
        'file_number' => '123-44-5678',
        'receive_date' => Time.now.strftime('%Y-%m-%d %H:%M:%S'),
        'guid' => pa.saved_claim.guid,
        'zip_code' => '78504',
        'source' => 'va.gov',
        'doc_type' => pa.saved_claim.form_id
  }}
  let(:file) { fixture_file_upload(
    "#{::Rails.root}/spec/fixtures/pension/attachment.pdf", 'application/pdf')
  }
  let(:file_hash) { "a83abce1fea679b6f49c8ccdc7fa947710645d0b" } # sha1.hexdigest of above file
  let(:token) { "af022405-4e10-4025-b6f5-2f85570ccbb5" }
  let(:vbms_client) { double(VBMS::Client)}
  let(:vbms_init) { double(VBMS::Requests::InitializeUpload) }
  let(:vbms_upload) { double(VBMS::Requests::UploadDocument)}
  let(:pa) { build_stubbed(:pension_burial) } # a claim with persistent_attachments
  let(:upload) { described_class.new(file, metadata) }

  describe '#initialize' do
    context 'with a ClaimDocumentation::Uploader::UploadedFile File' do
      let(:claim_upload) { described_class.new(pa.file, metadata)}
      let(:uploaded_file) { claim_upload.instance_variable_get(:@file)}
      let(:filename) { claim_upload.instance_variable_get(:@filename)}
      before do
        allow(pa).to receive('file').and_return(file)
        allow(pa.file).to receive('class').and_return('ClaimDocumentation::Uploader::UploadedFile')
      end
      it 'loads the file' do
        expect(uploaded_file.path).to eq(pa.file.path)
      end
      it 'prepends the filename with a unique identifier' do
        expect(filename).to match("^([a-z0-9]+-){5}attachment.pdf")
      end
    end

    context 'with a PORO File' do
      let(:uploaded_file) { upload.instance_variable_get(:@file)}
      let(:filename) { upload.instance_variable_get(:@filename)}
      before do
        allow(file).to receive('class').and_return('File')
      end
      it 'loads the file' do
        expect(uploaded_file.path).to eq(file.path)
      end
      it 'prepends the filename with a unique identifier' do
        expect(filename).to match("^([a-z0-9]+-){5}#{File.basename(file.tempfile)}")
      end
    end

    it 'hashes the file\'s content' do
      allow(file).to receive('class').and_return('File')
      content_hash = upload.instance_variable_get('@metadata')['content_hash']
      expect(content_hash).to eq(file_hash)
    end
  end

  context 'uploading a file' do
    before do
      allow(file).to receive('class').and_return('File')
      allow(vbms_init).to receive('initialize')
      allow(upload).to receive('client').and_return(vbms_client)
    end
    
    it 'calls #upload_file!' do
      expect(upload).to receive('upload_file!').once
    end

    it 'calls #fetch_upload_token' do
      allow(vbms_client).to receive('send_request')
      expect(upload).to receive(:fetch_upload_token).once
    end

    it 'calls #upload' do
      allow(upload).to receive(:fetch_upload_token).and_return(token)
      allow(upload).to receive(:upload).with(:token)
      expect(upload).to receive(:upload).with(token).once
    end

    it 'generates an upload request with file and metadata' do
      allow(upload).to receive(:upload).and_return true
      expect(vbms_client).to receive(:send_request) do |request|
        expect(request.kind_of? VBMS::Requests::InitializeUpload).to be(true)
        request.instance_values.each do |var, val|
          expect(request.instance_values[var]).to_not be_nil
        end
        expect(request.instance_values['new_mail']).to be_truthy
      end
    end

    it 'uploads document to vbms with token and file' do
      allow(upload).to receive(:fetch_upload_token).and_return(token)
      expect(vbms_client).to receive(:send_request) do |request|
        expect(request.kind_of? VBMS::Requests::UploadDocument).to be(true)
        filepath = upload.instance_variable_get(:@file).tempfile.path
        expect(request.instance_values['filepath']).to eq(filepath)
        expect(request.instance_values['upload_token']).to eq(token)
      end
    end

    after do
      upload.upload_file!
    end
  end
end
