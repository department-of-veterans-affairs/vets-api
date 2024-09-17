# frozen_string_literal: true

require 'rails_helper'

describe AttachmentSerializer do
  include Rails.application.routes.url_helpers

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

  it 'includes :message_id' do
    expect(attributes['message_id']).to eq attachment.message_id
  end

  it 'includes :attachment_size' do
    expect(attributes['attachment_size']).to eq attachment.attachment_size
  end

  it 'includes :download link' do
    expected_url = v0_message_attachment_url(attachment.message_id, attachment.id)
    expect(links['download']).to eq expected_url
  end
end
