# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::AttachmentSerializer do
  let(:attachment) { build_stubbed(:attachment) }

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(attachment, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to eq attachment.id.to_s
  end

  it 'includes :name' do
    expect(rendered_attributes[:name]).to eq attachment.name
  end

  context 'when object attachment_size is greater than 0' do
    it 'includes :attachment_size' do
      expect(rendered_attributes[:attachment_size]).to eq attachment.attachment_size
    end
  end

  context 'when object attachment_size is less than or equal to 0' do
    let(:rendered_hash) do
      empty_attachment = build_stubbed(:attachment, attachment_size: 0)
      ActiveModelSerializers::SerializableResource.new(empty_attachment, { serializer: described_class }).as_json
    end

    it 'includes :attachment_size' do
      expect(rendered_hash[:data][:attributes][:attachment_size]).to be_nil
    end
  end

  it 'includes :download link' do
    expected_url = Mobile::UrlHelper.new.v0_message_attachment_url(attachment.message_id, attachment.id)
    expect(rendered_hash[:data][:links][:download]).to eq expected_url
  end
end
