# frozen_string_literal: true

require 'rails_helper'
require 'common/file_helpers'
require 'simple_forms_api_submission/s3'

describe SimpleFormsApiSubmission::S3 do
  let(:region) { 'test-region' }
  let(:access_key_id) { 'test-access-key' }
  let(:secret_access_key) { 'test-secret-key' }
  let(:bucket_name) { 'test-bucket' }
  let(:bucket) { instance_double(Aws::S3::Bucket) }
  let(:object) { instance_double(Aws::S3::Object) }

  # rubocop:disable Style/HashSyntax
  let(:s3_instance) do
    SimpleFormsApiSubmission::S3.new(
      region: region,
      access_key_id: access_key_id,
      secret_access_key: secret_access_key,
      bucket_name: bucket_name
    )
  end
  # rubocop:enable Style/HashSyntax

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
          .to eq({ success: false, error_message: "S3 Upload failure for #{file_path}: upload failed" })
      end
    end
  end
end
