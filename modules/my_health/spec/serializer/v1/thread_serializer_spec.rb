# frozen_string_literal: true

require 'rails_helper'

describe MyHealth::V1::ThreadsSerializer, type: :serializer do
  subject { serialize(thread, serializer_class: described_class) }

  let(:thread) { build(:message_thread) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:links) { data['links'] }

  it 'includes :id' do
    expect(data['id']).to eq thread.thread_id.to_s
  end

  it 'includes :type' do
    expect(data['type']).to eq 'message_threads'
  end

  it 'includes :thread_id' do
    expect(attributes['thread_id']).to eq thread.thread_id
  end

  it 'includes :folder_id' do
    expect(attributes['folder_id']).to eq thread.folder_id
  end

  it 'includes :message_id' do
    expect(attributes['message_id']).to eq thread.message_id
  end

  it 'includes :thread_page_size' do
    expect(attributes['thread_page_size']).to eq thread.thread_page_size
  end

  it 'includes :message_count' do
    expect(attributes['message_count']).to eq thread.message_count
  end

  it 'includes :category' do
    expect(attributes['category']).to eq thread.category
  end

  it 'includes :subject' do
    expect(attributes['subject']).to eq thread.subject
  end

  it 'includes :triage_group_name' do
    expect(attributes['triage_group_name']).to eq thread.triage_group_name
  end

  it 'includes :sent_date' do
    expect_time_eq(attributes['sent_date'], thread.sent_date)
  end

  it 'includes :draft_date' do
    expect_time_eq(attributes['draft_date'], thread.draft_date)
  end

  it 'includes :sender_id' do
    expect(attributes['sender_id']).to eq thread.sender_id
  end

  it 'includes :sender_name' do
    expect(attributes['sender_name']).to eq thread.sender_name
  end

  it 'includes :recipient_name' do
    expect(attributes['recipient_name']).to eq thread.recipient_name
  end

  it 'includes :recipient_id' do
    expect(attributes['recipient_id']).to eq thread.recipient_id
  end

  it 'includes :proxySender_name' do
    expect(attributes['proxy_sender_name']).to eq thread.proxySender_name
  end

  it 'includes :has_attachment' do
    expect(attributes['has_attachment']).to eq thread.thread_has_attachment
  end

  it 'includes :unsent_drafts' do
    expect(attributes['unsent_drafts']).to eq thread.unsent_drafts
  end

  it 'includes :unread_messages' do
    expect(attributes['unread_messages']).to eq thread.unread_messages
  end

  it 'includes :self link' do
    expected_url = MyHealth::UrlHelper.new.v1_thread_url(thread.thread_id)
    expect(links['self']).to eq expected_url
  end
end
