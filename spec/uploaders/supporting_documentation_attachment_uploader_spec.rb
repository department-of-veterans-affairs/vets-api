# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupportingDocumentationAttachmentUploader do
  subject { described_class.new(guid) }

  let(:guid) { '1234' }

  it 'whitelists image and pdf files' do
    expect(subject.extension_whitelist).to match_array %w[pdf png gif tiff tif jpeg jpg]
  end

  it 'returns a store directory containing guid' do
    expect(subject.store_dir).to eq "supporting_documentation_attachments/#{guid}"
  end

  it 'throws an error if no guid is given' do
    blank_uploader = described_class.new(nil)
    expect { blank_uploader.store_dir }.to raise_error(RuntimeError, 'missing guid')
  end
end
