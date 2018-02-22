# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSSClaimDocumentUploader do
  let(:document_uploader) { described_class.new('1234', '11') }
  let(:uploader_with_tiff) do
    File.open('spec/fixtures/evss_claim/image.TIF') do |f|
      document_uploader.store!(f)
    end

    document_uploader
  end
  let(:uploader_with_jpg) do
    File.open('spec/fixtures/evss_claim/converted_image.TIF.jpg') do |f|
      document_uploader.store!(f)
    end

    document_uploader
  end
  subject { document_uploader }

  describe 'initialize' do
    context 'when uploads are disabled' do
      it 'should set storage to file' do
        with_settings(Settings.evss.s3, uploads_enabled: false) do
          expect(subject.class.storage).to eq(CarrierWave::Storage::File)
        end
      end
    end
    context 'when uploads are set to nil' do
      it 'should set storage to file' do
        with_settings(Settings.evss.s3, uploads_enabled: nil) do
          expect(subject.class.storage).to eq(CarrierWave::Storage::File)
        end
      end
    end
    context 'when uploads are enabled' do
      it 'should set storage to fog' do
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

      it 'should read from converted' do
        expect(converted).to receive(:read)
        subject.read_for_upload
      end
    end

    context 'with no converted image' do
      before do
        expect(converted).to receive(:present?).and_return(true)
        expect(converted).to receive(:file).and_return(OpenStruct.new(exists?: false))
      end

      it 'should read from the base file' do
        expect(subject).to receive(:read)
        subject.read_for_upload
      end
    end
  end

  describe '#final_filename' do
    it 'should return the right filename' do
      [uploader_with_tiff, uploader_with_jpg].each do |uploader|
        expect(uploader.final_filename).to eq('converted_image.TIF.jpg')
      end
    end
  end

  describe 'converted version' do
    it 'should convert tiff files to jpg' do
      expect(MimeMagic.by_magic(uploader_with_tiff.converted.file.read).type).to eq(
        'image/jpeg'
      )
    end

    it 'shouldnt convert if the file isnt tiff' do
      expect(uploader_with_jpg.converted_exists?).to eq(false)
    end
  end

  describe '#store_dir' do
    it 'omits the tracked item id if it is nil' do
      subject = described_class.new('1234abc', nil)
      expect(subject.store_dir).to eq('evss_claim_documents/1234abc')
    end

    it 'includes the uuid and tracked item id' do
      subject = described_class.new('1234abc', '13')
      expect(subject.store_dir).to eq('evss_claim_documents/1234abc/13')
    end
  end

  describe '#store!' do
    it 'raises an error when the file is larger than 25 megabytes' do
      file = double(size: 25.megabytes + 1)
      expect { subject.store!(file) }.to raise_error(CarrierWave::UploadError)
    end
  end
end
