# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DisabilityClaimDocumentUploader do
  subject { described_class.new }

  describe 'initialize' do
    context 'when EVSS_AWS_ACCESS_CREDS is not set' do
      it 'should set storage to file' do
        stub_const('EVSS_AWS_ACCESS_CREDS', nil)
        expect(subject.class.storage).to eq(CarrierWave::Storage::File)
      end
    end
    context 'when EVSS_AWS_ACCESS_CREDS is set' do
      it 'should set storage to fog' do
        stub_const('EVSS_AWS_ACCESS_CREDS', aws_access_key_id: 'aws_access_key_id',
                                            aws_secret_access_key: 'aws_secret_access_key')
        env_vars = {
          EVSS_S3_UPLOADS: 'true',
          EVSS_S3_BUCKET: 'evss_s3_bucket',
          EVSS_S3_REGION: 'evss_s3_region'
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
