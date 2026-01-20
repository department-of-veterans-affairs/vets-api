# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PdfUpload::S3Uploader do
  subject(:uploader) { described_class.new(directory:, config:) }

  let(:directory) { '1.19.26-Form21P-534EZ' }
  let(:config) { Config::Options.new(region: 'us-east-2', bucket: 'test-bucket') }
  let(:s3_client) { instance_double(Aws::S3::Client) }
  let(:presigner) { instance_double(Aws::S3::Presigner) }

  before do
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
    allow(Aws::S3::Presigner).to receive(:new).and_return(presigner)
  end

  describe '#initialize' do
    context 'with valid parameters' do
      it 'creates an uploader instance' do
        expect(uploader).to be_a(described_class)
      end
    end

    context 'with missing directory' do
      let(:directory) { nil }

      it 'raises a ValidationError' do
        expect { uploader }.to raise_error(
          PdfUpload::S3Uploader::ValidationError,
          'The S3 directory is missing.'
        )
      end
    end

    context 'with blank directory' do
      let(:directory) { '' }

      it 'raises a ValidationError' do
        expect { uploader }.to raise_error(
          PdfUpload::S3Uploader::ValidationError,
          'The S3 directory is missing.'
        )
      end
    end

    context 'with missing config' do
      let(:config) { nil }

      it 'raises a ValidationError' do
        expect { uploader }.to raise_error(
          PdfUpload::S3Uploader::ValidationError,
          'The configuration is missing.'
        )
      end
    end
  end

  describe '#store!' do
    let(:file_content) { 'PDF content here' }
    let(:filename) { 'test-form.pdf' }
    let(:file) { instance_double(File, read: file_content, path: "/tmp/#{filename}", size: 1024) }

    before do
      allow(s3_client).to receive(:put_object)
    end

    context 'with a valid PDF file' do
      it 'uploads the file to S3' do
        uploader.store!(file)

        expect(s3_client).to have_received(:put_object).with(
          bucket: 'test-bucket',
          key: "#{directory}/#{filename}",
          body: file_content,
          server_side_encryption: 'AES256',
          acl: 'private'
        )
      end
    end

    context 'with a file that has original_filename' do
      let(:original_filename) { 'original-name.pdf' }
      let(:file) do
        double(
          'UploadedFile',
          read: file_content,
          path: '/tmp/temp-file.pdf',
          original_filename:,
          size: 1024
        )
      end

      it 'uses original_filename for the S3 key' do
        uploader.store!(file)

        expect(s3_client).to have_received(:put_object).with(
          hash_including(key: "#{directory}/#{original_filename}")
        )
      end
    end

    context 'with a nil file' do
      it 'raises a ValidationError' do
        expect { uploader.store!(nil) }.to raise_error(
          PdfUpload::S3Uploader::ValidationError,
          'Invalid file object provided for upload.'
        )
      end
    end

    context 'with an object that does not respond to :read' do
      it 'raises a ValidationError' do
        expect { uploader.store!('not a file') }.to raise_error(
          PdfUpload::S3Uploader::ValidationError,
          'Invalid file object provided for upload.'
        )
      end
    end

    context 'with an object that has no filename or path' do
      let(:file) { instance_double(StringIO, read: file_content) }

      it 'raises a ValidationError' do
        expect { uploader.store!(file) }.to raise_error(
          PdfUpload::S3Uploader::ValidationError,
          'Cannot determine filename from file object.'
        )
      end
    end

    context 'with a disallowed file extension' do
      let(:file) { instance_double(File, read: file_content, path: '/tmp/malicious.exe', size: 1024) }

      it 'raises a ValidationError' do
        expect { uploader.store!(file) }.to raise_error(
          PdfUpload::S3Uploader::ValidationError,
          "File extension 'exe' not allowed"
        )
      end
    end

    context 'with an empty file extension' do
      let(:file) { instance_double(File, read: file_content, path: '/tmp/noextension', size: 1024) }

      it 'raises a ValidationError' do
        expect { uploader.store!(file) }.to raise_error(
          PdfUpload::S3Uploader::ValidationError,
          "File extension '' not allowed"
        )
      end
    end

    context 'with a file exceeding MAX_FILE_SIZE' do
      let(:file) { instance_double(File, read: file_content, path: '/tmp/huge.pdf', size: 151.megabytes) }

      it 'raises a ValidationError' do
        expect { uploader.store!(file) }.to raise_error(
          PdfUpload::S3Uploader::ValidationError,
          "File exceeds maximum size of #{150.megabytes} bytes"
        )
      end
    end

    context 'with a file at exactly MAX_FILE_SIZE' do
      let(:file) { instance_double(File, read: file_content, path: '/tmp/large.pdf', size: 150.megabytes) }

      it 'uploads successfully' do
        uploader.store!(file)
        expect(s3_client).to have_received(:put_object)
      end
    end

    context 'when S3 returns an error' do
      let(:file) { instance_double(File, read: file_content, path: '/tmp/test.pdf', size: 1024) }

      before do
        allow(s3_client).to receive(:put_object).and_raise(
          Aws::S3::Errors::ServiceError.new(nil, 'S3 is down')
        )
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error' do
        expect { uploader.store!(file) }.to raise_error(PdfUpload::S3Uploader::UploadError)

        expect(Rails.logger).to have_received(:error).with(/S3 upload failed for test.pdf/)
      end

      it 'raises an UploadError' do
        expect { uploader.store!(file) }.to raise_error(
          PdfUpload::S3Uploader::UploadError,
          'Upload failed: S3 is down'
        )
      end
    end
  end

  describe '#get_s3_link' do
    let(:file_path) { "#{directory}/21P-534EZ_abc123.pdf" }
    let(:presigned_url) { 'https://test-bucket.s3.amazonaws.com/signed-url' }

    before do
      allow(presigner).to receive(:presigned_url).and_return(presigned_url)
    end

    it 'returns a presigned URL' do
      result = uploader.get_s3_link(file_path)
      expect(result).to eq(presigned_url)
    end

    it 'calls presigner with correct parameters' do
      uploader.get_s3_link(file_path)

      expect(presigner).to have_received(:presigned_url).with(
        :get_object,
        bucket: 'test-bucket',
        key: file_path,
        expires_in: 30.minutes.to_i,
        response_content_disposition: 'attachment; filename="21P-534EZ_abc123.pdf"'
      )
    end

    context 'with a custom filename' do
      let(:custom_filename) { 'custom-download-name.pdf' }

      it 'uses the custom filename in content disposition' do
        uploader.get_s3_link(file_path, custom_filename)

        expect(presigner).to have_received(:presigned_url).with(
          :get_object,
          hash_including(response_content_disposition: "attachment; filename=\"#{custom_filename}\"")
        )
      end
    end
  end

  describe 'S3 client configuration' do
    before do
      allow(s3_client).to receive(:put_object)
      allow(presigner).to receive(:presigned_url)
    end

    it 'initializes S3 client with the configured region' do
      uploader.store!(instance_double(File, read: 'content', path: '/tmp/test.pdf', size: 100))

      expect(Aws::S3::Client).to have_received(:new).with(region: 'us-east-2')
    end

    it 'initializes presigner with the S3 client' do
      uploader.get_s3_link('some/path.pdf')

      expect(Aws::S3::Presigner).to have_received(:new).with(client: s3_client)
    end
  end
end
