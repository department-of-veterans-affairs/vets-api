# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DisabilityClaimDocumentUploader do
  subject { described_class.new('1234', '11') }

  describe 'initialize' do
    context 'when EVSS_S3_UPLOADS is "false"' do
      it 'should set storage to file' do
        ClimateControl.modify(EVSS_S3_UPLOADS: 'false') do
          expect(subject.class.storage).to eq(CarrierWave::Storage::File)
        end
      end
    end
    context 'when EVSS_S3_UPLOADS is nil' do
      it 'should set storage to file' do
        ClimateControl.modify(EVSS_S3_UPLOADS: nil) do
          expect(subject.class.storage).to eq(CarrierWave::Storage::File)
        end
      end
    end
    context 'when EVSS_S3_UPLOADS is "true"' do
      it 'should set storage to fog' do
        env_vars = {
          EVSS_S3_UPLOADS: 'true',
          EVSS_AWS_S3_BUCKET: 'evss_s3_bucket',
          EVSS_AWS_S3_REGION: 'evss_s3_region',
          EVSS_AWS_ACCESS_KEY_ID: 'aws_access_key_id',
          EVSS_AWS_SECRET_ACCESS_KEY: 'aws_secret_access_key'
        }
        ClimateControl.modify(env_vars) do
          expect(subject.class.storage).to eq(CarrierWave::Storage::Fog)
          expect(subject.fog_credentials).to eq(provider: 'AWS',
                                                aws_access_key_id: 'aws_access_key_id',
                                                aws_secret_access_key: 'aws_secret_access_key',
                                                region: 'evss_s3_region')
          expect(subject.fog_public).to eq(false)
          expect(subject.fog_directory).to eq('evss_s3_bucket')
        end
      end
    end
  end

  describe '#store!' do
    it 'raises an error when the file is larger than 25 megabytes' do
      file = double(size: 25.megabytes + 1)
      expect { subject.store!(file) }.to raise_error(CarrierWave::UploadError)
    end
  end
end
