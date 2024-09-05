# frozen_string_literal: true

require 'rails_helper'

describe MessagesSerializer, type: :serializer do
  subject { serialize(message, serializer_class: described_class) }

  let(:message) { build_stubbed(:message, :with_attachments) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:links) { data['links'] }

  it 'includes :id' do
    expect(data['id'].to_i).to eq(message.id)
  end

  it 'includes :message_id' do
    expect(attributes['message_id']).to eq(message.id)
  end

  it 'includes :category' do
    expect(attributes['category']).to eq(message.category)
  end

  it 'includes :subject' do
    expect(attributes['subject']).to eq(message.subject)
  end

  it 'includes :body' do
    expect(attributes['body']).to eq(message.body)
  end

  it 'includes :attachment' do
    expect(attributes['attachment']).to eq(message.attachment)
  end

  it 'includes :sent_date' do
    expect(Time.parse(attributes['sent_date']).utc).to eq(message.sent_date.utc)
  end

  it 'includes :sender_id' do
    expect(attributes['sender_id']).to eq(message.sender_id)
  end

  it 'includes :sender_name' do
    expect(attributes['sender_name']).to eq(message.sender_name)
  end

  it 'includes :recipient_id' do
    expect(attributes['recipient_id']).to eq(message.recipient_id)
  end

  it 'includes :recipient_name' do
    expect(attributes['recipient_name']).to eq(message.recipient_name)
  end

  it 'includes :read_receipt' do
    expect(attributes['read_receipt']).to eq(message.read_receipt)
  end

  it 'includes :self link' do
    expect(links['self']).to eq(v0_message_url(message.id))
  end
end
