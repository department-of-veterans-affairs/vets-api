# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::AttachmentSerializer, type: :serializer do
  subject { serialize(attachment, serializer_class: described_class) }

  let(:attachment) { build_stubbed(:attachment) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:links) { data['links'] }

  it 'includes :id' do
    expect(data['id']).to eq attachment.id.to_s
  end

  it 'includes :name' do
    expect(attributes['name']).to eq attachment.name
  end

  context 'when object attachment_size is greater than 0' do
    it 'includes :attachment_size' do
      expect(attributes['attachment_size']).to eq attachment.attachment_size
    end
  end

  context 'when object attachment_size is less than or equal to 0' do
    let(:attachment) { build_stubbed(:attachment, attachment_size: 0) }

    it 'includes :attachment_size' do
      expect(attributes['attachment_size']).to be_nil
    end
  end

  it 'includes :download link' do
    expected_url = Mobile::UrlHelper.new.v0_message_attachment_url(attachment.message_id, attachment.id)
    expect(links['download']).to eq expected_url
  end
end
