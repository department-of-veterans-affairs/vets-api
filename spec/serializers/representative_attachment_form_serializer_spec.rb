# frozen_string_literal: true

require 'rails_helper'

describe RepresentativeAttachmentFormSerializer, type: :serializer do
  subject { serialize(attachment, serializer_class: described_class) }

  # requires create instead of build for the attached file
  let(:attachment) { create(:va_form_pdf) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq attachment.id.to_s
  end

  it 'includes :confirmationCode' do
    expect(attributes['confirmationCode']).to eq attachment.guid
  end

  it 'includes :name' do
    expect(attributes['name']).to eq attachment.original_filename
  end

  it 'includes :size' do
    expect(attributes['size']).to eq attachment.size
  end

  it 'includes :warnings' do
    expect(attributes['warnings']).to eq attachment.warnings
  end
end
