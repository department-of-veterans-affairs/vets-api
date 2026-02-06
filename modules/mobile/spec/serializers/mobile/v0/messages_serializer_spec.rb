# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::MessagesSerializer, type: :serializer do
  subject { serialize(message, serializer_class: described_class) }

  let(:message) { build_stubbed(:message) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:links) { data['links'] }

  it 'includes :id' do
    expect(data['id']).to eq message.id.to_s
  end

  it 'includes :message_id' do
    expect(attributes['message_id']).to eq message.id
  end

  it 'includes :category' do
    expect(attributes['category']).to eq message.category
  end

  it 'includes :subject' do
    expect(attributes['subject']).to eq message.subject
  end

  it 'includes :body' do
    expect(attributes['body']).to eq message.body
  end

  it 'includes :attachment' do
    expect(attributes['attachment']).to eq message.attachment
  end

  it 'includes :sent_date' do
    expect_time_eq(attributes['sent_date'], message.sent_date)
  end

  it 'includes :sender_id' do
    expect(attributes['sender_id']).to eq message.sender_id
  end

  it 'includes :sender_name' do
    expect(attributes['sender_name']).to eq message.sender_name
  end

  it 'includes :recipient_id' do
    expect(attributes['recipient_id']).to eq message.recipient_id
  end

  it 'includes :recipient_name' do
    expect(attributes['recipient_name']).to eq message.recipient_name
  end

  it 'includes :read_receipt' do
    expect(attributes['read_receipt']).to eq message.read_receipt
  end

  it 'includes :triage_group_name' do
    expect(attributes['triage_group_name']).to eq message.triage_group_name
  end

  it 'includes :proxy_sender_name' do
    expect(attributes['proxy_sender_name']).to eq message.proxy_sender_name
  end

  it 'includes :self link' do
    expected_url = Mobile::UrlHelper.new.v0_message_url(message.id)
    expect(links['self']).to eq expected_url
  end

  it 'includes :reply_disabled' do
    expect(attributes['reply_disabled']).to eq message.reply_disabled
  end
end
