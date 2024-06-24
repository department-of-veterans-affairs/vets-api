# frozen_string_literal: true

require 'rails_helper'

describe MyHealth::V1::MessagesSerializer do
  let(:message) { build_stubbed(:message) }

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(message, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to eq message.id.to_s
  end

  it 'includes :message_id' do
    expect(rendered_attributes[:message_id]).to eq message.id
  end

  it 'includes :category' do
    expect(rendered_attributes[:category]).to eq message.category
  end

  it 'includes :subject' do
    expect(rendered_attributes[:subject]).to eq message.subject
  end

  it 'includes :body' do
    expect(rendered_attributes[:body]).to eq message.body
  end

  it 'includes :attachment' do
    expect(rendered_attributes[:attachment]).to eq message.attachment
  end

  it 'includes :sent_date' do
    expect(rendered_attributes[:sent_date]).to eq message.sent_date
  end

  it 'includes :sender_id' do
    expect(rendered_attributes[:sender_id]).to eq message.sender_id
  end

  it 'includes :sender_name' do
    expect(rendered_attributes[:sender_name]).to eq message.sender_name
  end

  it 'includes :recipient_id' do
    expect(rendered_attributes[:recipient_id]).to eq message.recipient_id
  end

  it 'includes :recipient_name' do
    expect(rendered_attributes[:recipient_name]).to eq message.recipient_name
  end

  it 'includes :read_receipt' do
    expect(rendered_attributes[:read_receipt]).to eq message.read_receipt
  end

  it 'includes :triage_group_name' do
    expect(rendered_attributes[:triage_group_name]).to eq message.triage_group_name
  end

  it 'includes :proxy_sender_name' do
    expect(rendered_attributes[:proxy_sender_name]).to eq message.proxy_sender_name
  end

  it 'includes :self link' do
    expected_url = MyHealth::UrlHelper.new.v1_message_url(message.id)
    expect(rendered_hash[:data][:links][:self]).to eq expected_url
  end
end
