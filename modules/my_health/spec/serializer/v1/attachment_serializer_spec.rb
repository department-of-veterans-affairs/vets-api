# frozen_string_literal: true

require 'rails_helper'

describe MyHealth::V1::AttachmentSerializer, type: :serializer do
  subject { serialize(attachment, serializer_class: described_class) }

  let(:attachment) { build_stubbed(:attachment) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:links) { data['links'] }

  it 'includes :id' do
    expect(data['id']).to eq attachment.id.to_s
  end

  it 'includes :type' do
    expect(data['type']).to eq 'attachments'
  end

  it 'includes :name' do
    expect(attributes['name']).to eq attachment.name
  end

  it 'includes :attachment_size' do
    expect(attributes['attachment_size']).to eq attachment.attachment_size
  end

  it 'includes :download link' do
    expected_url = MyHealth::UrlHelper.new.v1_message_attachment_url(attachment.message_id, attachment.id)
    expect(links['download']).to eq expected_url
  end
end
