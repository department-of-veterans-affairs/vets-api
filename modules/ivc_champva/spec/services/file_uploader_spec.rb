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

    context 'when at least one PDF upload fails:' do
      before do
        allow(uploader).to receive(:upload).and_return([400, 'Upload failed'])
      end

      it 'raises an error' do
        # Updated this test to account for new error being raised. This is so submissions are blocked
        # from completing if any files fail to make it to S3. Formerly, the expectation was:
        # `expect(uploader.handle_uploads).to eq([[400, 'Upload failed'], [400, 'Upload failed']])`
        expect { uploader.handle_uploads }.to raise_error(StandardError, /Upload failed/)
      end
    end

    context 'when FMP single file upload flipper is enabled' do
      let(:form_id) { 'vha_10_7959f_2' }
      let(:combined_pdf_path) { File.join('tmp/', "#{metadata['uuid']}_#{form_id}_combined.pdf") }
      let(:file_paths) do
        ['modules/ivc_champva/spec/fixtures/pdfs/vha_10_7959f_2-filled.pdf',
         'modules/ivc_champva/spec/fixtures/images/test_image.pdf',
         'spec/fixtures/files/doctors-note.pdf']
      end
      # let(:uploader) { IvcChampva::FileUploader.new(form_id, metadata, file_paths, insert_db_row) }

      before do
        allow(Flipper).to receive(:enabled?).with(:champva_fmp_single_file_upload, @current_user).and_return(true)
        allow(FileUtils).to receive(:rm_f)
      end

      it 'combines PDFs and uploads as a single file' do
        expect(IvcChampva::PdfCombiner).to receive(:combine)
          .with(combined_pdf_path, file_paths.compact)
          .and_return(combined_pdf_path)

        expect(uploader).to receive(:upload)
          .with(File.basename(combined_pdf_path), combined_pdf_path, anything)
          .and_return([200])

        expect(uploader).to receive(:generate_and_upload_meta_json).and_return([200, nil])

        result = uploader.handle_uploads
        expect(result).to eq([200, nil])

        expect(FileUtils).to have_received(:rm_f).with(combined_pdf_path)
      end

      it 'handles errors during PDF combination' do
        expect(IvcChampva::PdfCombiner).to receive(:combine)
          .with(combined_pdf_path, file_paths.compact)
          .and_raise(StandardError.new('PDF combination failed'))

        expect(FileUtils).to receive(:rm_f).with(combined_pdf_path)

        expect { uploader.handle_uploads }.to raise_error(StandardError, 'PDF combination failed')
      end

      it 'handles meta data upload failures' do
        expect(IvcChampva::PdfCombiner).to receive(:combine)
          .with(combined_pdf_path, file_paths.compact)
          .and_return(combined_pdf_path)

        expect(uploader).to receive(:upload)
          .with(File.basename(combined_pdf_path), combined_pdf_path, anything)
          .and_return([200])

        expect(uploader).to receive(:generate_and_upload_meta_json)
          .and_return([400, 'Metadata upload failed'])

        result = uploader.handle_uploads
        expect(result).to eq([400, 'Metadata upload failed'])

        expect(FileUtils).to have_received(:rm_f).with(combined_pdf_path)
      end

      it 'returns metadata upload results when require_all_s3_success is enabled' do
        allow(Flipper).to receive(:enabled?).with(:champva_require_all_s3_success, @current_user).and_return(true)

        expect(IvcChampva::PdfCombiner).to receive(:combine)
          .with(combined_pdf_path, file_paths.compact)
          .and_return(combined_pdf_path)

        expect(uploader).to receive(:upload)
          .with(File.basename(combined_pdf_path), combined_pdf_path, anything)
          .and_return([200])

        expect(uploader).to receive(:generate_and_upload_meta_json)
          .and_return([400, 'Metadata upload failed'])

        result = uploader.handle_uploads
        expect(result).to eq([400, 'Metadata upload failed'])

        expect(FileUtils).to have_received(:rm_f).with(combined_pdf_path)
      end
    end
  end

  describe '#insert_form' do
    it 're-raises the exception when inserting into the DB fails' do
      allow(IvcChampvaForm).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(IvcChampvaForm.new))

      expect do
        uploader.send(:insert_form, 'test_file.pdf', [400, 'Upload failed'])
      end.to raise_error(ActiveRecord::RecordInvalid)
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
