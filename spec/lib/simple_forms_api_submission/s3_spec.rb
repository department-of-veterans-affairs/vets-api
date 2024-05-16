# frozen_string_literal: true

require 'rails_helper'
require 'common/file_helpers'
require 'simple_forms_api_submission/s3'

describe SimpleFormsApiSubmission::S3 do
  let(:region) { 'test-region' }
  let(:access_key_id) { 'test-access-key' }
  let(:secret_access_key) { 'test-secret-key' }
  let(:bucket_name) { 'test-bucket' }
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
end
