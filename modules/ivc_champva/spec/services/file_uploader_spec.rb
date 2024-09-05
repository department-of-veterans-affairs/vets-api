# frozen_string_literal: true

require 'rails_helper'

describe IvcChampva::FileUploader do
  let(:form_id) { '123' }
  let(:metadata) do
    { 'uuid' => '4171e61a-03b5-49f3-8717-dbf340310473',
      'attachment_ids' => ['Social Security card', 'Birth certificate'] }
  end
  let(:file_paths) { ['tmp/file1.pdf', 'tmp/file2.png'] }
  let(:insert_db_row) { false }
  let(:uploader) { IvcChampva::FileUploader.new(form_id, metadata, file_paths, insert_db_row) }

  describe '#handle_uploads' do
    context 'when all PDF uploads succeed' do
      before do
        allow(uploader).to receive(:upload).and_return([200])
      end

      it 'generates and uploads meta JSON' do
        expect(uploader).to receive(:generate_and_upload_meta_json).and_return([200, nil])
        uploader.handle_uploads
      end
    end

    context 'when at least one PDF upload fails' do
      before do
        allow(uploader).to receive(:upload).and_return([400, 'Upload failed'])
      end

      it 'returns an array of upload results' do
        expect(uploader.handle_uploads).to eq([[400, 'Upload failed'], [400, 'Upload failed']])
      end
    end
  end

  describe '#generate_and_upload_meta_json' do
    let(:meta_file_path) { "tmp/#{metadata['uuid']}_#{form_id}_metadata.json" }

    before do
      allow(File).to receive(:write)
      allow(uploader).to receive(:upload).and_return([200, nil])
      allow(FileUtils).to receive(:rm_f)
    end

    it 'writes metadata to a JSON file and uploads it' do
      expect(File).to receive(:write).with(meta_file_path, metadata.to_json)
      expect(uploader).to receive(:upload).with(
        "#{metadata['uuid']}_#{form_id}_metadata.json",
        meta_file_path
      ).and_return([200, nil])
      uploader.send(:generate_and_upload_meta_json)
    end

    context 'when meta upload succeeds' do
      it 'deletes the meta file and returns success' do
        expect(FileUtils).to receive(:rm_f).with(meta_file_path)
        expect(uploader.send(:generate_and_upload_meta_json)).to eq([200, nil])
      end
    end

    context 'when meta upload fails' do
      before do
        allow(uploader).to receive(:upload).and_return([400, 'Upload failed'])
      end

      it 'returns the upload error' do
        expect(uploader.send(:generate_and_upload_meta_json)).to eq([400, 'Upload failed'])
      end
    end
  end

  describe '#upload' do
    let(:s3_client) { double('S3Client') }

    before do
      allow(uploader).to receive(:client).and_return(s3_client)
    end

    it 'uploads the file to S3 and returns the upload status' do
      expect(s3_client).to receive(:put_object).and_return({ success: true })
      expect(uploader.send(:upload, 'file_name', 'file_path', 'attachment_id')).to eq([200])
    end

    context 'when upload fails' do
      it 'returns the error message' do
        expect(s3_client).to receive(:put_object).and_return({ success: false, error_message: 'Upload failed' })
        expect(uploader.send(:upload,
                             'file_name',
                             'file_path',
                             'attachment_id')).to eq([400, 'Upload failed'])
      end
    end

    context 'when unexpected response from S3' do
      it 'returns an unexpected response error' do
        expect(s3_client).to receive(:put_object).and_return(nil)
        expect(uploader.send(:upload,
                             'file_name',
                             'file_path',
                             attachment_ids: 'attachment_ids')).to eq([500, 'Unexpected response from S3 upload'])
      end
    end
  end
end
