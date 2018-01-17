# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MessageSerializer, type: :serializer do
  let(:message) { build :message }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:links) { data['links'] }

  subject { serialize(message, serializer_class: described_class) }

  it 'should include id' do
    expect(data['id'].to_i).to eq(message.id)
  end

  it 'should include the category' do
    expect(attributes['message_id']).to eq(message.id)
  end

  it 'should include the category' do
    expect(attributes['category']).to eq(message.category)
  end

  it 'should include the subject' do
    expect(attributes['subject']).to eq(message.subject)
  end

  it 'should include the body' do
    expect(attributes['body']).to eq(message.body)
  end

  it 'should include the attachment status' do
    expect(attributes['attachment']).to eq(message.attachment)
  end

  it 'should include the sent date' do
    expect(Time.parse(attributes['sent_date']).utc).to eq(message.sent_date.utc)
  end

  it 'should include sender id' do
    expect(attributes['sender_id']).to eq(message.sender_id)
  end

  it 'should include sender name' do
    expect(attributes['sender_name']).to eq(message.sender_name)
  end

  it 'should include recipient id' do
    expect(attributes['recipient_id']).to eq(message.recipient_id)
  end

  it 'should include recipient name' do
    expect(attributes['recipient_name']).to eq(message.recipient_name)
  end

  it 'should include a read reciept' do
    expect(attributes['read_receipt']).to eq(message.read_receipt)
  end

  it 'should include a link to itself' do
    expect(links['self']).to eq(v0_message_url(message.id))
  end
end
