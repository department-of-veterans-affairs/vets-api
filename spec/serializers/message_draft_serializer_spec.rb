# frozen_string_literal: true
require 'rails_helper'

RSpec.describe MessageDraftSerializer, type: :serializer do
  let(:draft) { build :message_draft }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:links) { data['links'] }

  subject { serialize(draft, serializer_class: described_class) }

  it 'should include id' do
    expect(data['id'].to_i).to eq(draft.id)
  end

  it 'should include the category' do
    expect(attributes['message_id']).to eq(draft.id)
  end

  it 'should include the category' do
    expect(attributes['category']).to eq(draft.category)
  end

  it 'should include the subject' do
    expect(attributes['subject']).to eq(draft.subject)
  end

  it 'should include the body' do
    expect(attributes['body']).to eq(draft.body)
  end

  it 'should include the attachment status' do
    expect(attributes['attachment']).to eq(draft.attachment)
  end

  it 'should include the sent date' do
    expect(Time.parse(attributes['sent_date']).utc).to eq(draft.sent_date.utc)
  end

  it 'should include sender id' do
    expect(attributes['sender_id']).to eq(draft.sender_id)
  end

  it 'should include sender name' do
    expect(attributes['sender_name']).to eq(draft.sender_name)
  end

  it 'should include recipient id' do
    expect(attributes['recipient_id']).to eq(draft.recipient_id)
  end

  it 'should include recipient name' do
    expect(attributes['recipient_name']).to eq(draft.recipient_name)
  end

  it 'should include a read reciept' do
    expect(attributes['read_receipt']).to eq(draft.read_receipt)
  end

  it 'should include a link to itself' do
    expect(links['self']).to eq(v0_message_url(draft.id))
  end
end
