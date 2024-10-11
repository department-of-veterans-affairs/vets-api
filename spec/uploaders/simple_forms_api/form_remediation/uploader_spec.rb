# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')
require 'simple_forms_api/form_remediation/configuration/vff_config'

module SimpleFormsApi
  module FormRemediation
    RSpec.describe Uploader do
      describe '#initialize' do
        subject(:new) { described_class.new(directory:, config:) }

        before do
          allow(Settings.vff_simple_forms).to(
            receive(:aws).and_return(OpenStruct.new(region: 'region', bucket: 'bucket'))
          )
        end

        let(:config) { Configuration::VffConfig.new }
        let(:directory) { '/some/path' }

        it 'allows image, pdf, json, csv, and text files' do
          expect(new.extension_allowlist).to match_array %w[bmp csv gif jpeg jpg json pdf png tif tiff txt zip]
        end

        it 'returns a store directory containing benefits_intake_uuid' do
          expect(new.store_dir).to eq(directory)
        end

        describe 'when config is nil' do
          let(:config) { nil }

          it 'throws an error' do
            expect { new }.to raise_exception(RuntimeError, 'The configuration is missing.')
          end
        end

        describe 'when directory is nil' do
          let(:directory) { nil }

          it 'throws an error' do
            expect { new }.to raise_exception(RuntimeError, 'The S3 directory is missing.')
          end
        end
      end
    end
  end
end
