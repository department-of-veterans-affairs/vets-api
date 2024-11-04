# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')
require 'simple_forms_api/form_remediation/configuration/vff_config'

module SimpleFormsApi
  module FormRemediation
    RSpec.describe Uploader, :upload_helpers do
      let(:config) { Configuration::VffConfig.new }
      let(:directory) { '/some/path' }
      let(:uploader_instance) { described_class.new(directory:, config:) }
      let(:bucket_name) { 'bucket' }
      let(:source_file_name) { 'doctors-note.jpg' }
      let(:source_file_path) { "spec/fixtures/files/#{source_file_name}" }
      let(:source_file) { Rack::Test::UploadedFile.new(source_file_path, 'image/jpg') }
      let(:s3_client_double) { instance_double(Aws::S3::Client) }
      let(:s3_bucket_double) { instance_double(Aws::S3::Bucket) }
      let(:s3_object_double) { instance_double(Aws::S3::Object) }
      let(:s3_resource) { Aws::S3::Resource.new(client: s3_client_double) }

      before do
        allow(Settings.vff_simple_forms.aws).to receive_messages(region: 'region', bucket: bucket_name)
        allow(Aws::S3::Client).to receive(:new).and_return(s3_client_double)
        allow(Aws::S3::Resource).to receive(:new).and_return(s3_resource)
        allow(s3_resource).to receive(:bucket).with(bucket_name).and_return(s3_bucket_double)
      end

      describe 'configuration' do
      end

      describe '#initialize' do
        subject(:new) { uploader_instance }

        it 'allows image, pdf, json, csv, and text files' do
          expect(new.extension_allowlist).to match_array %w[bmp csv gif jpeg jpg json pdf png tif tiff txt zip]
        end

        it 'returns a store directory containing the given directory' do
          expect(new.store_dir).to eq(directory)
        end

        it 'uses an AWS store' do
          expect(described_class.storage).to eq(CarrierWave::Storage::AWS)
          expect(new._storage?).to eq(true)
          expect(new._storage).to eq(CarrierWave::Storage::AWS)
        end

        it 'sets aws config' do
          expect(new.aws_acl).to eq('private')
          expect(new.aws_bucket).to eq(bucket_name)
          expect(new.aws_attributes).to eq(server_side_encryption: 'AES256', retry_mode: 'standard', retry_limit: 3)
          expect(new.aws_credentials).to eq(region: 'region')
        end

        context 'when config is nil' do
          let(:config) { nil }

          it 'throws an error' do
            expect { new }.to raise_exception(RuntimeError, 'The configuration is missing.')
          end
        end

        context 'when directory is nil' do
          let(:directory) { nil }

          it 'throws an error' do
            expect { new }.to raise_exception(RuntimeError, 'The S3 directory is missing.')
          end
        end
      end

      describe '#size_range' do
        it 'sets the store_dir to the initialized argument' do
          expect(uploader_instance.size_range).to eq((1.byte)...(150.megabytes))
        end
      end

      describe '#store_dir' do
        it 'sets the store_dir to the initialized argument' do
          expect(uploader_instance.store_dir).to eq(directory)
        end
      end

      describe '#store!' do
        context 'with invalid extension' do
          let(:source_file) { Rack::Test::UploadedFile.new('spec/fixtures/files/va.poop', 'application/poop') }

          it 'raises an error' do
            expect { uploader_instance.store!(source_file) }.to raise_error do |error|
              expect(error).to be_instance_of(CarrierWave::IntegrityError)
            end
          end
        end

        context 'with invalid content-type' do
          let(:source_file) do
            Rack::Test::UploadedFile.new('spec/fixtures/files/invalid_content_type.exe', 'application/exe')
          end

          it 'raises an error' do
            expect { uploader_instance.store!(source_file) }.to raise_error do |error|
              expect(error).to be_instance_of(CarrierWave::IntegrityError)
              expect(error.message).to eq(a_string_including("You can't upload application/exe files."))
            end
          end
        end

        context 'with file size below the minimum' do
          let(:source_file) { Rack::Test::UploadedFile.new('spec/fixtures/files/empty-file.jpg', 'image/jpg') }

          it 'raises an error' do
            expect { uploader_instance.store!(source_file) }.to raise_error do |error|
              expect(error).to be_instance_of(CarrierWave::IntegrityError)
              expect(error.message).to eq(
                'We couldn’t upload your file because it’s too small. File size needs to be greater than 1 Byte'
              )
            end
          end
        end

        context 'with file size above the maximum' do
          let(:source_file) { Rack::Test::UploadedFile.new('spec/fixtures/files/doctors-note.jpg', 'image/jpg') }

          before do
            expect(uploader_instance).to receive(:size_range).and_return((1.byte)...(3.bytes))
          end

          it 'raises an error' do
            expect { uploader_instance.store!(source_file) }.to raise_error do |error|
              expect(error).to be_instance_of(CarrierWave::IntegrityError)
              expect(error.message).to eq(
                'We couldn’t upload your file because it’s too large. File size needs to be less than 2 Bytes'
              )
            end
          end
        end
      end

      describe '#get_s3_link' do
        subject(:get_s3_link) { uploader_instance.get_s3_link(file_path, filename) }

        let(:file_path) { 'some/file/path' }
        let(:filename) { 'file.txt' }

        before do
          allow(s3_bucket_double).to receive(:object).with(file_path).and_return(s3_object_double)
          allow(s3_object_double).to receive(:presigned_url).and_return("https://s3.amazonaws.com/#{bucket_name}/#{file_path}")
        end

        it 'returns a presigned URL for the S3 object' do
          result = get_s3_link
          expect(result).to eq("https://s3.amazonaws.com/#{bucket_name}/#{file_path}")
          expect(s3_object_double).to have_received(:presigned_url).with(
            :get,
            expires_in: 30.minutes.to_i,
            response_content_disposition: "attachment; filename=\"#{filename}\""
          )
        end
      end

      describe '#get_s3_file' do
        subject(:get_s3_file) { uploader_instance.get_s3_file(from_path, to_path) }

        let(:from_path) { 'some/file/path' }
        let(:to_path) { '/local/path/file.txt' }

        before { allow(s3_bucket_double).to receive(:object).with(from_path).and_return(s3_object_double) }

        context 'when a transient error occurs during download' do
          before do
            call_count = 0
            allow(s3_object_double).to receive(:get) do
              call_count += 1
              raise Aws::S3::Errors::ServiceError.new(nil, 'Service outage') if call_count < 3

              true
            end
          end

          it 'retries the download until it succeeds' do
            expect { get_s3_file }.not_to raise_error
            expect(s3_object_double).to have_received(:get).exactly(3).times
          end
        end
      end
    end
  end
end
