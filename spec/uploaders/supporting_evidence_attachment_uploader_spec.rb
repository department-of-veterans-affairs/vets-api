# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupportingEvidenceAttachmentUploader do
  subject { described_class.new(guid) }

  let(:guid) { '1234' }

  it 'whitelists image, pdf, and text files' do
    expect(subject.extension_white_list).to match_array %w[pdf png gif tiff tif jpeg jpg bmp txt]
  end

  it 'returns a store directory containing guid' do
    expect(subject.store_dir).to eq "disability_compensation_supporting_form/#{guid}"
  end

  it 'throws an error if no guid is given' do
    blank_uploader = described_class.new(nil)
    expect { blank_uploader.store_dir }.to raise_error(RuntimeError, 'missing guid')
  end
end
