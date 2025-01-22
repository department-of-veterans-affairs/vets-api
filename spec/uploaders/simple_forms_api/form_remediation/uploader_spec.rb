# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')
require 'simple_forms_api/form_remediation/configuration/vff_config'

RSpec.describe SimpleFormsApi::FormRemediation::Uploader do
  let(:config) do
    instance_double(
      SimpleFormsApi::FormRemediation::Configuration::VffConfig,
      s3_settings: OpenStruct.new(region: 'region', bucket: bucket_name)
    )
  end
  let(:directory) { '/some/path' }
  let(:bucket_name) { 'bucket' }
  let(:mock_config) { instance_double(Config::Options) }
  let(:uploader_instance) { described_class.new(directory:, config:) }

  before do
    allow(Rails.logger).to receive(:error).and_call_original
    allow(Rails.logger).to receive(:info).and_call_original
  end

  describe '#initialize' do
    subject(:new) { uploader_instance }

    it 'uses an AWS store', skip: 'TODO: Fix Flaky Test' do
      expect(described_class.storage).to eq(CarrierWave::Storage::AWS)
      expect(new._storage?).to be(true)
      expect(new._storage).to eq(CarrierWave::Storage::AWS)
    end

    it 'sets aws config' do
      expect(new.aws_acl).to eq('private')
      expect(new.aws_bucket).to eq(bucket_name)
      expect(new.aws_attributes).to eq(server_side_encryption: 'AES256')
      expect(new.aws_credentials).to eq(region: 'region')
    end

    context 'when config is nil' do
      let(:config) { nil }

      it 'throws an error' do
        expect { new }.to raise_exception(RuntimeError, a_string_including('The configuration is missing.'))
      end
    end

    context 'when directory is nil' do
      let(:directory) { nil }

      it 'throws an error' do
        expect { new }.to raise_exception(RuntimeError, a_string_including('The S3 directory is missing.'))
      end
    end
  end

  describe '#size_range' do
    subject(:size_range) { uploader_instance.size_range }

    it 'returns a range from 1 byte to 150 megabytes' do
      expect(size_range).to eq((1.byte)...(150.megabytes))
    end
  end

  describe '#extension_allowlist' do
    subject(:extension_allowlist) { uploader_instance.extension_allowlist }

    it 'allows image, pdf, json, csv, and text files' do
      expect(extension_allowlist).to match_array %w[bmp csv gif jpeg jpg json pdf png tif tiff txt zip]
    end
  end

  describe '#store_dir' do
    subject(:store_dir) { uploader_instance.store_dir }

    it 'returns a store directory containing the given directory' do
      expect(store_dir).to eq(directory)
    end
  end

  describe '#store!' do
    subject(:store!) { uploader_instance.store!(file) }

    let(:file) { instance_double(CarrierWave::SanitizedFile, filename: 'test_file.txt') }

    before { allow(config).to receive(:handle_error) }

    context 'when the file is nil' do
      let(:file) { nil }
      let(:error_message) { 'An error occurred while uploading the file.' }

      it 'logs an error and returns' do
        store!
        expect(config).to have_received(:handle_error).with(error_message, an_instance_of(RuntimeError))
      end
    end

    context 'when the file is not nil' do
      it 'stores the file' do
        expect { store! }.not_to raise_exception
      end
    end

    context 'when an aws service error occurs' do
      let(:aws_service_error) { Aws::S3::Errors::ServiceError.new(nil, 'Service error') }

      before do
        allow_any_instance_of(CarrierWave::Uploader::Base).to receive(:store!).and_raise(aws_service_error)
        allow(SimpleFormsApi::FormRemediation::UploadRetryJob).to receive(:perform_async)
      end

      it 'logs an error and retries the upload' do
        expect { store! }.not_to raise_error
        expect(Rails.logger).to(
          have_received(:error).with("Upload failed for #{file.filename}. Enqueuing for retry.", aws_service_error)
        )
        expect(SimpleFormsApi::FormRemediation::UploadRetryJob).to(
          have_received(:perform_async).with(file, directory, config)
        )
      end
    end
  end

  describe '#get_s3_link' do
    subject(:get_s3_link) { uploader_instance.get_s3_link(file_path, filename) }

    let(:file_path) { 'file_path' }
    let(:filename) { 'filename' }
    let(:s3_obj) { instance_double(Aws::S3::Object) }

    before do
      allow(uploader_instance).to receive(:s3_obj).with(file_path).and_return(s3_obj)
      allow(s3_obj).to receive(:presigned_url).with(
        :get,
        expires_in: 30.minutes.to_i,
        response_content_disposition: "attachment; filename=\"#{filename}\""
      ).and_return('url')
    end

    it 'returns a presigned URL' do
      expect(get_s3_link).to eq('url')
    end
  end

  describe '#get_s3_file' do
    subject(:get_s3_file) { uploader_instance.get_s3_file(from_path, to_path) }

    let(:from_path) { 'from_path' }
    let(:to_path) { 'to_path' }
    let(:s3_obj) { instance_double(Aws::S3::Object) }

    before do
      allow(uploader_instance).to receive(:s3_obj).with(from_path).and_return(s3_obj)
      allow(s3_obj).to receive(:get).with(response_target: to_path)
    end

    it 'downloads the file to the given path' do
      expect(get_s3_file).to be_nil
    end
  end
end
