# frozen_string_literal: true

require 'rails_helper'

describe MyHealth::V1::MessageDetailsSerializer, type: :serializer do
  subject { serialize(message, serializer_class: described_class) }

  let(:message) { build(:message_thread_details, :with_attachments_for_thread, has_attachments: true) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:links) { data['links'] }

  it 'includes :id' do
    expect(data['id']).to eq message.message_id.to_s
  end

  it 'includes :body' do
    expect(attributes['body']).to eq message.message_body
  end

  it 'includes :message_id' do
    expect(attributes['message_id']).to eq message.message_id
  end

  it 'includes :thread_id' do
    expect(attributes['thread_id']).to eq message.thread_id
  end

  it 'includes :folder_id' do
    expect(attributes['folder_id']).to eq message.folder_id
  end

  it 'includes :message_body' do
    expect(attributes['message_body']).to eq message.message_body
  end

  it 'includes :draft_date' do
    expect(attributes['draft_date']).to eq message.draft_date
  end

  it 'includes :to_date' do
    expect(attributes['to_date']).to eq message.to_date
  end

  it 'includes :has_attachments' do
    expect(attributes['has_attachments']).to eq message.has_attachments
  end

  it 'includes :oh_migration_phase' do
    expect(attributes['oh_migration_phase']).to eq message.oh_migration_phase
  end

  it 'includes :attachments' do
    expect(attributes['attachments'].size).to eq message.attachments.size
  end

  it 'includes attachments with objects' do
    first_attachment = message.attachments.first
    download = MyHealth::UrlHelper.new.v1_message_attachment_url(message.message_id, first_attachment[:attachment_id])
    expected_attachment = {
      id: first_attachment[:attachment_id],
      message_id: message.message_id,
      name: first_attachment[:attachment_name],
      attachment_size: first_attachment[:attachment_size],
      download:
    }
    expect(attributes['attachments'].first).to eq expected_attachment.deep_stringify_keys
  end

  it 'includes :self link' do
    expected_url = MyHealth::UrlHelper.new.v1_message_url(message.message_id)
    expect(links['self']).to eq expected_url
  end
end
