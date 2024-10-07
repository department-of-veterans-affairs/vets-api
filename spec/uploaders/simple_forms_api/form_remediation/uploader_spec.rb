# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VeteranFacingFormsRemediationUploader do
  subject { described_class.new(benefits_intake_uuid, directory) }

  before do
    allow(Settings.vff_simple_forms).to receive(:aws).and_return(OpenStruct.new(region: 'region', bucket: 'bucket'))
  end

  let(:benefits_intake_uuid) { SecureRandom.uuid }
  let(:directory) { '/some/path' }

  it 'allows image, pdf, json, csv, and text files' do
    expect(subject.extension_allowlist).to match_array %w[bmp csv gif jpeg jpg json pdf png tif tiff txt zip]
  end

  it 'returns a store directory containing benefits_intake_uuid' do
    expect(subject.store_dir).to eq(directory)
  end

  it 'throws an error if no benefits_intake_uuid is given' do
    expect { described_class.new(nil, directory) }.to raise_error(RuntimeError, 'The benefits_intake_uuid is missing.')
  end

  it 'throws an error if no directory is given' do
    expect { described_class.new(benefits_intake_uuid, nil) }.to(
      raise_error(RuntimeError, 'The s3 directory is missing.')
    )
  end
end
