# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSSClaimDocumentUploader do
  subject { document_uploader }

  let(:user_uuid) { SecureRandom.uuid }
  let(:document_uploader) { described_class.new(user_uuid, ['11', nil]) }

  let(:uploader_with_tiff) do
    f = Rack::Test::UploadedFile.new('spec/fixtures/evss_claim/image.TIF', 'image/tiff')
    document_uploader.store!(f)
    document_uploader
  end

  let(:uploader_with_jpg) do
    f = Rack::Test::UploadedFile.new('spec/fixtures/evss_claim/converted_image.TIF.jpg', 'image/jpeg')
    document_uploader.store!(f)
    document_uploader
  end

  after do
    FileUtils.rm_rf(Rails.root.glob(
                      'tmp/uploads/evss_claim_documents/**/*/*/**/*/*/evss_claim_documents/**/*/*/**/*/*'
                    ))
  end

  describe 'initialize' do
    context 'when uploads are disabled' do
      it 'sets storage to file' do
        with_settings(Settings.evss.s3, uploads_enabled: false) do
          expect(subject.class.storage).to eq(CarrierWave::Storage::File)
        end
      end
    end

    context 'when uploads are set to nil' do
      it 'sets storage to file' do
        with_settings(Settings.evss.s3, uploads_enabled: nil) do
          expect(subject.class.storage).to eq(CarrierWave::Storage::File)
        end
      end
    end

    context 'when uploads are enabled' do
      it 'sets storage to fog' do
        with_settings(Settings.evss.s3, uploads_enabled: true) do
          expect(subject.class.storage).to eq(CarrierWave::Storage::AWS)
          expect(subject.aws_credentials).to eq(access_key_id: 'EVSS_S3_AWS_ACCESS_KEY_ID_XYZ',
                                                secret_access_key: 'EVSS_S3_AWS_SECRET_ACCESS_KEY_XYZ',
                                                region: 'evss_s3_region')
          expect(subject.aws_acl).to eq('private')
          expect(subject.aws_bucket).to eq('evss_s3_bucket')
        end
      end
    end
  end

  describe '#read_for_upload' do
    let(:converted) { double }

    before do
      allow(subject).to receive(:converted).and_return(converted)
    end

    context 'with a converted image' do
      before do
        expect(converted).to receive(:present?).and_return(true)
        expect(converted).to receive(:file).and_return(OpenStruct.new(exists?: true))
      end

      it 'reads from converted' do
        expect(converted).to receive(:read)
        subject.read_for_upload
      end
    end

    context 'with no converted image' do
      before do
        expect(converted).to receive(:present?).and_return(true)
        expect(converted).to receive(:file).and_return(OpenStruct.new(exists?: false))
      end

      it 'reads from the base file' do
        expect(subject).to receive(:read)
        subject.read_for_upload
      end
    end
  end

  describe '#final_filename', skip: 'flakey spec' do
    it 'returns the right filename' do
      [uploader_with_tiff, uploader_with_jpg].each do |uploader|
        expect(uploader.final_filename).to eq('converted_image_TIF.jpg')
      end
    end
  end

  describe 'converted version', skip: 'flakey specs' do
    it 'converts tiff files to jpg' do
      expect(MimeMagic.by_magic(uploader_with_tiff.converted.file.read).type).to eq(
        'image/jpeg'
      )
    end

    it 'shouldnt convert if the file isnt tiff' do
      expect(uploader_with_jpg.converted_exists?).to be(false)
    end

    [
      {
        path: 'files/doctors-note.gif',
        final_filename: 'converted_doctors-note_gif.png',
        description: 'misnamed png',
        binary_or_name_changes: true
      },
      {
        path: 'files/doctors-note.jpg',
        final_filename: 'converted_doctors-note_jpg.png',
        description: 'misnamed png',
        binary_or_name_changes: true
      },
      {
        path: 'files/va.gif',
        final_filename: 'va.gif',
        description: 'no change',
        binary_or_name_changes: false
      },
      {
        path: 'evss_claim/image.TIF',
        final_filename: 'converted_image_TIF.jpg',
        description: 'ext and filetype match /BUT/ tifs not allowed',
        binary_or_name_changes: true
      },
      {
        path: 'evss_claim/secretly_a_jpg.tif',
        final_filename: 'converted_secretly_a_jpg_tif.jpg',
        description: 'misnamed jpg',
        binary_or_name_changes: true
      },
      {
        path: 'evss_claim/secretly_a_tif.jpg',
        final_filename: 'converted_secretly_a_tif.jpg',
        description: "converted, but file extension doesn't change",
        binary_or_name_changes: true
      }
    ].each do |args|
      path, final_filename, description, binary_or_name_changes = args.values_at(
        :path, :final_filename, :description, :binary_or_name_changes
      )
      it "#{description}: #{path.split('/').last} -> #{final_filename}" do
        uploader = described_class.new '1234', ['11', nil]
        file = Rack::Test::UploadedFile.new "spec/fixtures/#{path}", "image/#{path.split('.').last}"
        uploader.store! file
        expect(uploader.converted_exists?).to eq binary_or_name_changes
        expect(uploader.final_filename).to eq(final_filename)
      end
    end
  end

  describe '#store_dir' do
    let(:user_uuid) { SecureRandom.uuid }
    let(:tracked_item_id) { '13' }
    let(:secondary_id) { SecureRandom.uuid }

    it 'omits the tracked item id if it is nil' do
      uploader = described_class.new(user_uuid, [nil, nil])
      expect(uploader.store_dir).to eq("evss_claim_documents/#{user_uuid}")
    end

    it 'includes the tracked item id if provided' do
      uploader = described_class.new(user_uuid, [tracked_item_id, nil])
      expect(uploader.store_dir).to eq("evss_claim_documents/#{user_uuid}/#{tracked_item_id}")
    end

    it 'includes both tracked item id and secondary id if provided' do
      uploader = described_class.new(user_uuid, [tracked_item_id, secondary_id])
      expect(uploader.store_dir).to eq("evss_claim_documents/#{user_uuid}/#{tracked_item_id}/#{secondary_id}")
    end

    it 'handles a case where user_uuid is missing or nil' do
      uploader = described_class.new(nil, [tracked_item_id, secondary_id])
      expect(uploader.store_dir).to eq("evss_claim_documents//#{tracked_item_id}/#{secondary_id}")
    end
  end
end
