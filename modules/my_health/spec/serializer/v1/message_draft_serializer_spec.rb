# frozen_string_literal: true

require 'rails_helper'

describe MyHealth::V1::MessageDraftSerializer, type: :serializer do
  subject { serialize(message, { serializer_class: described_class, include: [:attachments] }) }

  let(:message) { build_stubbed(:message, :with_attachments) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:relationships) { data['relationships'] }

  it 'includes :type relationship' do
    expect(data['type']).to eq 'message_drafts'
  end

  it 'includes :attachments relationship' do
    expect(relationships['attachments']['data'].size).to eq message.attachments.size
  end
end
