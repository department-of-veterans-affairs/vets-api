# frozen_string_literal: true

require 'rails_helper'
require 'common/file_helpers'

describe IvcChampva::S3 do
  let(:region) { 'test-region' }
  let(:bucket_name) { 'test-bucket' }
  let(:bucket) { instance_double(Aws::S3::Bucket) }
  let(:object) { instance_double(Aws::S3::Object) }

  let(:s3_instance) do
    IvcChampva::S3.new(
      region: region,
      bucket: bucket_name
    )
  end

  describe '#put_object' do
    let(:key) { 'test_file.pdf' }
    let(:file_path) { 'spec/fixtures/files/doctors-note.pdf' }

    context 'when upload is successful' do
      before do
        allow_any_instance_of(Aws::S3::Client).to receive(:put_object).and_return(true)
      end

      it 'returns success response' do
        expect(s3_instance.put_object(key, file_path)).to eq({ success: true })
      end
    end

    context 'when upload fails' do
      before do
        allow_any_instance_of(Aws::S3::Client).to receive(:put_object)
          .and_raise(Aws::S3::Errors::ServiceError.new(nil, 'upload failed'))
      end

      it 'returns error response' do
        expect(s3_instance.put_object(key, file_path))
          .to eq({ success: false, error_message: "S3 PutObject failure for #{file_path}: upload failed" })
      end
    end
  end

  describe '#upload_file' do
    let(:key) { 'test_form.pdf' }
    let(:file_path) { 'test_form.pdf' }

    context 'when upload is successful' do
      before do
        allow_any_instance_of(Aws::S3::Resource).to receive(:bucket).and_return(bucket)
        allow(bucket).to receive(:object).with(key).and_return(object)
        allow(object).to receive(:upload_file).and_return(true)
      end

      it 'returns success response' do
        expect(s3_instance.upload_file(key, file_path)).to eq({ success: true })
      end
    end

    context 'when upload fails' do
      before do
        allow_any_instance_of(Aws::S3::Resource).to receive(:bucket).and_return(bucket)
        allow(bucket).to receive(:object).with(key).and_return(object)
        allow(object).to receive(:upload_file).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'upload failed'))
      end

      it 'returns error response' do
        expect(s3_instance.upload_file(key, file_path))
          .to eq({ success: false, error_message: "S3 UploadFile failure for #{file_path}: upload failed" })
      end
    end
  end
end
