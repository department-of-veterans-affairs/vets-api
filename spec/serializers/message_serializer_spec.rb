# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MessageSerializer, type: :serializer do
  subject { serialize(message, { serializer_class: described_class, include: [:attachments] }) }

  let(:message) { build_stubbed(:message, :with_attachments) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:relationships) { data['relationships'] }

  it 'includes :id' do
    expect(data['id'].to_i).to eq(message.id)
  end

  it 'includes :type' do
    expect(data['type']).to eq 'messages'
  end

  it 'includes :attachments' do
    expect(relationships['attachments']['data'].size).to eq message.attachments.size
  end
end
