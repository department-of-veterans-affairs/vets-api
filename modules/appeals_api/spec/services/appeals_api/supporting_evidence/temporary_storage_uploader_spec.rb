# frozen_string_literal: true

require 'rails_helper'

module AppealsApi
  module SupportingEvidence
    RSpec.describe TemporaryStorageUploader do
      let(:appeal) { create(:notice_of_disagreement) }
      let(:uploader) { described_class.new(appeal.id, :notice_of_disagreement) }

      describe 'initialize' do
        context 'when uploads are disabled' do
          it 'sets storage to file' do
            with_settings(Settings.modules_appeals_api.s3, uploads_enabled: false) do
              expect(uploader.class.storage).to eq(CarrierWave::Storage::File)
            end
          end
        end

        context 'when uploads are set to nil' do
          it 'sets storage to file' do
            with_settings(Settings.modules_appeals_api.s3, uploads_enabled: nil) do
              expect(uploader.class.storage).to eq(CarrierWave::Storage::File)
            end
          end
        end
      end

      context 'when uploads are enabled' do
        it 'sets storage to AWS' do
          with_settings(Settings.modules_appeals_api.s3, uploads_enabled: true) do
            expect(uploader.class.storage).to eq(CarrierWave::Storage::AWS)
            expect(uploader.aws_credentials).to eq(access_key_id: 'aws_access_key_id',
                                                   secret_access_key: 'aws_secret_access_key',
                                                   region: 'region')
          end
        end
      end

      describe '#store_dir' do
        it 'builds from location/uuid' do
          expect(uploader.store_dir).to eq("notice_of_disagreement/#{appeal.id}")
        end
      end
    end
  end
end
