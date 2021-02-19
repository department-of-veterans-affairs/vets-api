# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSSClaimDocumentUploader do
  subject { document_uploader }

  def document_uploader
    described_class.new('1234', ['11', nil])
  end

  let(:uploader_with_tiff) do
    f = Rack::Test::UploadedFile.new('spec/fixtures/evss_claim/image.TIF', 'image/tiff')
    uploader = document_uploader
    uploader.store!(f)
    uploader
  end

  let(:uploader_with_jpg) do
    f = Rack::Test::UploadedFile.new('spec/fixtures/evss_claim/converted_image.TIF.jpg', 'image/jpeg')
    uploader = document_uploader
    uploader.store!(f)
    uploader
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

  describe '#filename' do
    it 'returns the right filename' do
      [uploader_with_tiff, uploader_with_jpg].each do |uploader|
        expect(uploader.filename).to eq('converted_image.TIF.jpg')
      end
    end
  end

  describe 'converts file' do
    it 'converts tiff files to jpg' do
      expect(MimeMagic.by_magic(uploader_with_tiff.file.read).type).to eq(
        'image/jpeg'
      )
    end

    it 'shouldnt convert if the file isnt tiff' do
      expect(MimeMagic.by_magic(uploader_with_jpg.file.read).type).to eq(
        'image/jpeg'
      )
    end
  end

  describe '#store_dir' do
    it 'omits the tracked item id if it is nil' do
      subject = described_class.new('1234abc', EVSSClaimDocument.new.uploader_ids)
      expect(subject.store_dir).to eq('evss_claim_documents/1234abc')
    end

    it 'includes the uuid and tracked item id' do
      subject = described_class.new('1234abc', ['13', nil])
      expect(subject.store_dir).to eq('evss_claim_documents/1234abc/13')
    end

    it 'includes both uuids' do
      uuid = SecureRandom.uuid
      subject = described_class.new('1234abc', [nil, uuid])
      expect(subject.store_dir).to eq("evss_claim_documents/1234abc/#{uuid}")
    end
  end

  describe '#store!' do
    it 'stores the file' do
      expect(uploader_with_tiff.file.present?).to be true
    end

    it 'throws an error if you try to store twice to the same uploader' do
      expect { uploader_with_tiff.store! }.to raise_error EVSSClaimDocumentUploader::StoreCalledTwiceError
    end
  end
end
