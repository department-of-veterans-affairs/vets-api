# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::Attachment, type: :model do
  it 'is a FormAttachment model' do
    expect(described_class.ancestors).to include(FormAttachment)
  end

  it 'has an uploader configured' do
    expect(described_class::ATTACHMENT_UPLOADER_CLASS).to eq(Form1010cg::PoaUploader)
  end
end
