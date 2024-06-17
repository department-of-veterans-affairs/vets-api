# frozen_string_literal: true

require 'rails_helper'

describe MessagesSerializer, type: :serializer do
  subject { serialize(message, serializer_class: described_class) }

  let(:message) { build_stubbed(:message, :with_attachments) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:links) { data['links'] }

  it 'includes id' do
    expect(data['id'].to_i).to eq(message.id)
  end

  it 'includes the message id' do
    expect(attributes['message_id']).to eq(message.id)
  end

  it 'includes the category' do
    expect(attributes['category']).to eq(message.category)
  end

  it 'includes the subject' do
    expect(attributes['subject']).to eq(message.subject)
  end

  it 'includes the body' do
    expect(attributes['body']).to eq(message.body)
  end

  it 'includes the attachment status' do
    expect(attributes['attachment']).to eq(message.attachment)
  end

  it 'includes the sent date' do
    expect(Time.parse(attributes['sent_date']).utc).to eq(message.sent_date.utc)
  end

  it 'includes sender id' do
    expect(attributes['sender_id']).to eq(message.sender_id)
  end

  it 'includes sender name' do
    expect(attributes['sender_name']).to eq(message.sender_name)
  end

  it 'includes recipient id' do
    expect(attributes['recipient_id']).to eq(message.recipient_id)
  end

  it 'includes recipient name' do
    expect(attributes['recipient_name']).to eq(message.recipient_name)
  end

  it 'includes a read receipt' do
    expect(attributes['read_receipt']).to eq(message.read_receipt)
  end

  it 'includes a link to itself' do
    expect(links['self']).to eq(v0_message_url(message.id))
  end
end
