# frozen_string_literal: true

require 'rails_helper'

describe PersistentAttachmentSerializer, type: :serializer do
  subject { serialize(attachment, serializer_class: described_class) }

  # requires create instead of build for the attached file
  let(:attachment) { create(:pension_burial) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq attachment.id.to_s
  end

  it 'includes :confirmation_code' do
    expect(attributes['confirmation_code']).to eq attachment.guid
  end

  it 'includes :name' do
    expect(attributes['name']).to eq attachment.original_filename
  end

  it 'includes :size' do
    expect(attributes['size']).to eq attachment.size
  end
end
