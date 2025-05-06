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
      region:,
      bucket: bucket_name
    )
  end

  describe '#put_object' do
    let(:key) { 'test_file.pdf' }
    let(:file_path) { 'spec/fixtures/files/doctors-note.pdf' }

    context 'when upload is successful' do
      let(:http_response_double) { double('http_response', status_code: 200) }
      let(:context_double) { double('context', http_response: http_response_double) }
      let(:response_double) do
        double('Aws::S3::Types::PutObjectOutput', context: context_double)
      end

      before do
        allow_any_instance_of(Aws::S3::Client).to receive(:put_object).and_return(response_double)
        allow(Flipper).to receive(:enabled?)
          .with(:champva_log_all_s3_uploads, @current_user)
          .and_return(true)
      end

      it 'returns success response' do
        expect(s3_instance.put_object(key, file_path)).to eq({ success: true })
      end

      it 'tracks successful upload' do
        expect(s3_instance.monitor).to receive(:track_all_successful_s3_uploads).with(key)
        s3_instance.put_object(key, file_path)
      end
    end

    context 'when upload fails with non-200 status' do
      let(:http_response_double) { double('http_response', status_code: 500) }
      let(:context_double) { double('context', http_response: http_response_double) }
      let(:response_double) do
        double(
          'Aws::S3::Types::PutObjectOutput',
          context: context_double,
          body: double(read: 'Internal Server Error')
        )
      end

      before do
        allow_any_instance_of(Aws::S3::Client).to receive(:put_object).and_return(response_double)
        allow(Flipper).to receive(:enabled?)
          .with(:champva_log_all_s3_uploads, @current_user)
          .and_return(true)
      end

      it 'returns failure response with status code and body' do
        expected_error_message = "S3 PutObject failure for #{file_path}: Status code: 500, Body: Internal Server Error"
        expect(s3_instance.put_object(key, file_path)).to eq({ success: false, error_message: expected_error_message })
      end

      it 'logs the error message' do
        expect(Rails.logger).to receive(:error).with(
          "S3 PutObject failure for #{file_path}: Status code: 500, Body: Internal Server Error"
        )
        s3_instance.put_object(key, file_path)
      end
    end

    context 'when upload raises an exception' do
      before do
        allow_any_instance_of(Aws::S3::Client).to receive(:put_object).and_raise(
          Aws::S3::Errors::ServiceError.new(nil, 'Service Unavailable')
        )
        allow(Flipper).to receive(:enabled?)
          .with(:champva_log_all_s3_uploads, @current_user)
          .and_return(true)
      end

      it 'returns failure response with exception message' do
        expect(s3_instance.put_object(key,
                                      file_path)).to eq({ success: false,
                                                          error_message: 'S3 PutObject unexpected error: Service
                                                          Unavailable'.squish })
      end

      it 'logs the exception message' do
        expect(Rails.logger).to receive(:error).with('S3 PutObject unexpected error: Service Unavailable')
        s3_instance.put_object(key, file_path)
      end
    end

    context 'when response body does not respond to read' do
      let(:http_response_double) { double('http_response', status_code: 500) }
      let(:context_double) { double('context', http_response: http_response_double) }
      let(:response_double) do
        double('Aws::S3::Types::PutObjectOutput', context: context_double, body: 'Internal Server Error')
      end

      before do
        allow_any_instance_of(Aws::S3::Client).to receive(:put_object).and_return(response_double)
        allow(Flipper).to receive(:enabled?)
          .with(:champva_log_all_s3_uploads, @current_user)
          .and_return(true)
      end

      it 'returns failure response with status code' do
        expected_error_message = "S3 PutObject failure for #{file_path}: Status code: 500"
        expect(s3_instance.put_object(key, file_path)).to eq({ success: false, error_message: expected_error_message })
      end

      it 'logs the error message' do
        expect(Rails.logger).to receive(:error).with("S3 PutObject failure for #{file_path}: Status code: 500")
        s3_instance.put_object(key, file_path)
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
