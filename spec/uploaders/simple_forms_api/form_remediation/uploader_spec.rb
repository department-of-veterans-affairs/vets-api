# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')
require 'simple_forms_api/form_remediation/configuration/vff_config'

module SimpleFormsApi
  module FormRemediation
    RSpec.describe Uploader do
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
    end
  end
end
