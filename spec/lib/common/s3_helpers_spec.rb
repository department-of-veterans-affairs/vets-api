# frozen_string_literal: true

require 'rails_helper'
require 'common/s3_helpers'

RSpec.describe Common::S3Helpers do
  let(:s3_resource) { instance_double(Aws::S3::Resource) }
  let(:s3_client) { instance_double(Aws::S3::Client) }
  let(:s3_bucket) { instance_double(Aws::S3::Bucket) }
  let(:s3_object) { instance_double(Aws::S3::Object) }
  let(:bucket_name) { 'test-bucket' }
  let(:key) { 'test-file.pdf' }
  let(:file_path) { 'tmp/test.pdf' }
  let(:content_type) { 'application/pdf' }

  before do
    allow(s3_resource).to receive(:client).and_return(s3_client)
    allow(s3_resource).to receive(:bucket).with(bucket_name).and_return(s3_bucket)
    allow(s3_bucket).to receive(:object).with(key).and_return(s3_object)
  end

  describe '.upload_file' do
    context 'when TransferManager is available' do
      let(:transfer_manager) { instance_double(Aws::S3::TransferManager) }

      before do
        allow(Aws::S3::TransferManager).to receive(:new).with(client: s3_client).and_return(transfer_manager)
      end

      it 'uploads using TransferManager with correct options' do
        expect(transfer_manager).to receive(:upload_file).with(
          file_path,
          bucket: bucket_name,
          key:,
          content_type:,
          multipart_threshold: CarrierWave::Storage::AWSOptions::MULTIPART_TRESHOLD
        )

        described_class.upload_file(
          s3_resource:,
          bucket: bucket_name,
          key:,
          file_path:,
          content_type:
        )
      end

      it 'includes ACL when provided' do
        expect(transfer_manager).to receive(:upload_file).with(
          file_path,
          bucket: bucket_name,
          key:,
          content_type:,
          acl: 'public-read',
          multipart_threshold: CarrierWave::Storage::AWSOptions::MULTIPART_TRESHOLD
        )

        described_class.upload_file(
          s3_resource:,
          bucket: bucket_name,
          key:,
          file_path:,
          content_type:,
          acl: 'public-read'
        )
      end

      it 'includes server_side_encryption when provided' do
        expect(transfer_manager).to receive(:upload_file).with(
          file_path,
          bucket: bucket_name,
          key:,
          content_type:,
          server_side_encryption: 'AES256',
          multipart_threshold: CarrierWave::Storage::AWSOptions::MULTIPART_TRESHOLD
        )

        described_class.upload_file(
          s3_resource:,
          bucket: bucket_name,
          key:,
          file_path:,
          content_type:,
          server_side_encryption: 'AES256'
        )
      end

      it 'returns true by default' do
        allow(transfer_manager).to receive(:upload_file)

        result = described_class.upload_file(
          s3_resource:,
          bucket: bucket_name,
          key:,
          file_path:,
          content_type:
        )

        expect(result).to be true
      end

      it 'returns S3 object when return_object is true' do
        allow(transfer_manager).to receive(:upload_file)

        result = described_class.upload_file(
          s3_resource:,
          bucket: bucket_name,
          key:,
          file_path:,
          content_type:,
          return_object: true
        )

        expect(result).to eq(s3_object)
      end
    end

    context 'when TransferManager is not available' do
      before do
        allow(Aws::S3).to receive(:const_defined?).with(:TransferManager).and_return(false)
      end

      it 'falls back to basic upload_file method' do
        expect(s3_object).to receive(:upload_file).with(file_path, content_type:)

        described_class.upload_file(
          s3_resource:,
          bucket: bucket_name,
          key:,
          file_path:,
          content_type:
        )
      end

      it 'includes ACL in fallback when provided' do
        expect(s3_object).to receive(:upload_file).with(
          file_path,
          content_type:,
          acl: 'public-read'
        )

        described_class.upload_file(
          s3_resource:,
          bucket: bucket_name,
          key:,
          file_path:,
          content_type:,
          acl: 'public-read'
        )
      end

      it 'includes server_side_encryption in fallback when provided' do
        expect(s3_object).to receive(:upload_file).with(
          file_path,
          content_type:,
          server_side_encryption: 'AES256'
        )

        described_class.upload_file(
          s3_resource:,
          bucket: bucket_name,
          key:,
          file_path:,
          content_type:,
          server_side_encryption: 'AES256'
        )
      end

      it 'returns true by default' do
        allow(s3_object).to receive(:upload_file)

        result = described_class.upload_file(
          s3_resource:,
          bucket: bucket_name,
          key:,
          file_path:,
          content_type:
        )

        expect(result).to be true
      end

      it 'returns S3 object when return_object is true' do
        allow(s3_object).to receive(:upload_file)

        result = described_class.upload_file(
          s3_resource:,
          bucket: bucket_name,
          key:,
          file_path:,
          content_type:,
          return_object: true
        )

        expect(result).to eq(s3_object)
      end
    end
  end
end
