# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DisabilityClaimDocumentUploader do
  subject { described_class.new('1234', '11') }

  describe 'initialize' do
    context 'when uploads are disabled' do
      it 'should set storage to file' do
        Settings.evss.s3.uploads_enabled = false
        expect(subject.class.storage).to eq(CarrierWave::Storage::File)
      end
    end
    context 'when uploads are set to nil' do
      it 'should set storage to file' do
        Settings.evss.s3.uploads_enabled = nil
        expect(subject.class.storage).to eq(CarrierWave::Storage::File)
        Settings.evss.s3.uploads_enabled = false
      end
    end
    context 'when uploads are enabled' do
      it 'should set storage to fog' do
        Settings.evss.s3.uploads_enabled = true

        expect(subject.class.storage).to eq(CarrierWave::Storage::AWS)
        expect(subject.aws_credentials).to eq(region: 'evss_s3_region')
        expect(subject.aws_acl).to eq('private')
        expect(subject.aws_bucket).to eq('evss_s3_bucket')
        Settings.evss.s3.uploads_enabled = false
      end
    end
  end

  describe '#store_dir' do
    it 'omits the tracked item id if it is nil' do
      subject = described_class.new('1234abc', nil)
      expect(subject.store_dir).to eq('disability_claim_documents/1234abc')
    end

    it 'includes the uuid and tracked item id' do
      subject = described_class.new('1234abc', '13')
      expect(subject.store_dir).to eq('disability_claim_documents/1234abc/13')
    end
  end

  describe '#store!' do
    it 'raises an error when the file is larger than 25 megabytes' do
      file = double(size: 25.megabytes + 1)
      expect { subject.store!(file) }.to raise_error(CarrierWave::UploadError)
    end
  end
end
