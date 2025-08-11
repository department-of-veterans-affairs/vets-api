# frozen_string_literal: true

require 'rails_helper'

describe PersistentAttachmentSerializer, type: :serializer do
  subject { serialize(attachment, serializer_class: described_class) }

  let(:attachment) do
    create(:persistent_attachment, guid: 'abc-123-guid').tap do |att|
      allow(att).to receive_messages(
        original_filename: 'doctors-note.pdf',
        size: 4567
      )
    end
  end

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
