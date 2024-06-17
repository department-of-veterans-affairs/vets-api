# frozen_string_literal: true

require 'rails_helper'

describe MyHealth::V1::ThreadsSerializer do
  let(:thread) { build(:message_thread) }

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(thread, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to eq thread.thread_id.to_s
  end

  it 'includes :thread_id' do
    expect(rendered_attributes[:thread_id]).to eq thread.thread_id
  end

  it 'includes :folder_id' do
    expect(rendered_attributes[:folder_id]).to eq thread.folder_id
  end

  it 'includes :message_id' do
    expect(rendered_attributes[:message_id]).to eq thread.message_id
  end

  it 'includes :thread_page_size' do
    expect(rendered_attributes[:thread_page_size]).to eq thread.thread_page_size
  end

  it 'includes :message_count' do
    expect(rendered_attributes[:message_count]).to eq thread.message_count
  end

  it 'includes :category' do
    expect(rendered_attributes[:category]).to eq thread.category
  end

  it 'includes :subject' do
    expect(rendered_attributes[:subject]).to eq thread.subject
  end

  it 'includes :triage_group_name' do
    expect(rendered_attributes[:triage_group_name]).to eq thread.triage_group_name
  end

  it 'includes :sent_date' do
    expect(rendered_attributes[:sent_date]).to eq thread.sent_date
  end

  it 'includes :draft_date' do
    expect(rendered_attributes[:draft_date]).to eq thread.draft_date
  end

  it 'includes :sender_id' do
    expect(rendered_attributes[:sender_id]).to eq thread.sender_id
  end

  it 'includes :sender_name' do
    expect(rendered_attributes[:sender_name]).to eq thread.sender_name
  end

  it 'includes :recipient_name' do
    expect(rendered_attributes[:recipient_name]).to eq thread.recipient_name
  end

  it 'includes :recipient_id' do
    expect(rendered_attributes[:recipient_id]).to eq thread.recipient_id
  end

  it 'includes :proxySender_name' do
    expect(rendered_attributes[:proxy_sender_name]).to eq thread.proxySender_name
  end

  it 'includes :has_attachment' do
    expect(rendered_attributes[:has_attachment]).to eq thread.has_attachment
  end

  it 'includes :unsent_drafts' do
    expect(rendered_attributes[:unsent_drafts]).to eq thread.unsent_drafts
  end

  it 'includes :unread_messages' do
    expect(rendered_attributes[:unread_messages]).to eq thread.unread_messages
  end

  it 'includes :self link' do
    expected_url = MyHealth::UrlHelper.new.v1_thread_url(thread.thread_id)
    expect(rendered_hash[:data][:links][:self]).to eq expected_url
  end
end
