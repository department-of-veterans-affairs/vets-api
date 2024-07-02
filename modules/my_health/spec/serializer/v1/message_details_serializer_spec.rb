# frozen_string_literal: true

require 'rails_helper'

describe MyHealth::V1::MessageDetailsSerializer do
  let(:message) { build(:message_thread_details, :with_attachments, has_attachments: true) }

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(message, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to eq message.message_id.to_s
  end

  it 'includes :body' do
    expect(rendered_attributes[:body]).to eq message.message_body
  end

  it 'includes :message_id' do
    expect(rendered_attributes[:message_id]).to eq message.message_id
  end

  it 'includes :thread_id' do
    expect(rendered_attributes[:thread_id]).to eq message.thread_id
  end

  it 'includes :folder_id' do
    expect(rendered_attributes[:folder_id]).to eq message.folder_id
  end

  it 'includes :message_body' do
    expect(rendered_attributes[:message_body]).to eq message.message_body
  end

  it 'includes :draft_date' do
    expect(rendered_attributes[:draft_date]).to eq message.draft_date
  end

  it 'includes :to_date' do
    expect(rendered_attributes[:to_date]).to eq message.to_date
  end

  it 'includes :has_attachments' do
    expect(rendered_attributes[:has_attachments]).to eq message.has_attachments
  end

  it 'includes :attachments' do
    expect(rendered_attributes[:attachments].size).to eq message.attachments.size
  end

  it 'includes attachments with objects' do
    download = MyHealth::UrlHelper.new.v1_message_attachment_url(message.message_id, message.send('attachment1_id'))
    expected_attachment = {
      id: message.send('attachment1_id'),
      message_id: message.message_id,
      name: message.send('attachment1_name'),
      attachment_size: message.send('attachment1_size'),
      download:
    }
    expect(rendered_attributes[:attachments].first).to eq expected_attachment
  end

  it 'includes :self link' do
    expected_url = MyHealth::UrlHelper.new.v1_message_url(message.message_id)
    expect(rendered_hash[:data][:links][:self]).to eq expected_url
  end
end
