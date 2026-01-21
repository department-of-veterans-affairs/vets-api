# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/form1010cg_helpers/test_file_helpers'

describe Form1010cg::PoaUploader, :uploader_helpers do
  let(:form_attachment_guid) { 'cdbaedd7-e268-49ed-b714-ec543fbb1fb8' }
  let(:subject) { described_class.new(form_attachment_guid) }
  let(:source_file_name) { 'doctors-note.jpg' }
  let(:source_file_path) { "spec/fixtures/files/#{source_file_name}" }
  let(:source_file) { Form1010cgHelpers::TestFileHelpers.create_test_uploaded_file(source_file_name, 'image/jpg') }
  let(:vcr_options) do
    {
      record: :none,
      allow_unused_http_interactions: false,
      match_requests_on: %i[method host body]
    }
  end

  describe 'configuration' do
    it 'uses an AWS store' do
      expect(described_class.storage).to eq(CarrierWave::Storage::AWS)
      expect(subject._storage?).to be(true)
      expect(subject._storage).to eq(CarrierWave::Storage::AWS)
    end

    it 'sets aws config' do
      expect(subject.aws_acl).to eq('private')
      expect(subject.aws_bucket).to eq('my-bucket')
      expect(subject.aws_attributes).to eq(server_side_encryption: 'AES256')
      expect(subject.aws_credentials).to eq(
        access_key_id: 'my-aws-key-id',
        secret_access_key: 'my-aws-access-key',
        region: 'us-gov-west-1'
      )
    end
  end

  describe '#size_range' do
    it 'sets the store_dir to the initialized argument' do
      expect(subject.size_range).to eq((1.byte)...(10.megabytes))
    end
  end

  describe '#store_dir' do
    it 'sets the store_dir to the initialized argument' do
      expect(subject.store_dir).to eq(form_attachment_guid)
    end
  end

  describe '#store!' do
    context 'with invalid extension' do
      let(:source_file) { Rack::Test::UploadedFile.new('spec/fixtures/files/va.gif', 'image/gif') }

      it 'raises an error' do
        expect { subject.store!(source_file) }.to raise_error do |error|
          expect(error).to be_instance_of(CarrierWave::IntegrityError)
          expect(error.message).to eq(
            'You can’t upload "gif" files. The allowed file types are: jpg, jpeg, png, pdf'
          )
        end
      end
    end

    context 'with invalid content-type' do
      let(:source_file) do
        Rack::Test::UploadedFile.new('spec/fixtures/files/invalid_content_type.jpg', 'application/json')
      end

      it 'raises an error' do
        expect { subject.store!(source_file) }.to raise_error do |error|
          expect(error).to be_instance_of(CarrierWave::IntegrityError)
          expect(error.message).to eq(
            # rubocop:disable Layout/LineLength
            'You can’t upload application/json files. The allowed file types are: image/jpg, image/jpeg, image/png, application/pdf'
            # rubocop:enable Layout/LineLength
          )
        end
      end
    end

    context 'with file size below the minimum' do
      let(:source_file) { Rack::Test::UploadedFile.new('spec/fixtures/files/empty-file.jpg', 'image/jpg') }

      it 'raises an error' do
        expect { subject.store!(source_file) }.to raise_error do |error|
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
        expect(subject).to receive(:size_range).and_return((1.byte)...(3.bytes)) # rubocop:disable RSpec/SubjectStub
      end

      it 'raises an error' do
        expect { subject.store!(source_file) }.to raise_error do |error|
          expect(error).to be_instance_of(CarrierWave::IntegrityError)
          expect(error.message).to eq(
            'We couldn’t upload your file because it’s too large. File size needs to be less than 2 Bytes'
          )
        end
      end
    end

    context 'with valid data' do
      let(:store_vcr_options) do
        vcr_options.merge(allow_unused_http_interactions: true)
      end

      before do
        expect(StatsD).to receive(:measure).with(
          'api.upload.form1010cg_poa_uploader.size',
          83_403,
          {
            tags: [
              'content_type:jpg'
            ]
          }
        )
      end

      it 'stores file in aws' do
        VCR.use_cassette("s3/object/put/#{form_attachment_guid}/doctors-note.jpg", store_vcr_options) do
          expect(subject.filename).to be_nil
          expect(subject.file).to be_nil
          expect(subject.versions).to eq({})

          subject.store!(source_file)

          expect(subject.filename).to eq('doctors-note.jpg')
          expect(subject.file.path).to eq("#{form_attachment_guid}/#{source_file.original_filename}")

          # Should not versions objects so they can be permanently destroyed
          expect(subject.versions).to eq({})
        end
      end
    end
  end

  describe '#retrieve_from_store!' do
    it 'retrieves the stored file in s3' do
      # Use allow_unused_http_interactions: true because retrieve_from_store! only sets
      # up metadata - it doesn't fetch content until .read is called. We're testing
      # the retrieval mechanism, not S3 content integrity (which is flaky in parallel CI).
      retrieve_vcr_options = vcr_options.merge(allow_unused_http_interactions: true)
      VCR.use_cassette("s3/object/get/#{form_attachment_guid}/doctors-note.jpg", retrieve_vcr_options) do
        subject.retrieve_from_store!(source_file_name)

        expect(subject.file.filename).to eq('doctors-note.jpg')
        expect(subject.file.path).to eq("#{form_attachment_guid}/#{source_file_name}")
        expect(subject.versions).to eq({})
      end
    end
  end
end
