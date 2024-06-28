# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::MessageSerializer do
  let(:message) { build_stubbed(:message, :with_attachments) }

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(message, { serializer: described_class }).as_json
  end
  let(:rendered_relationships) { rendered_hash[:data][:relationships] }

  it 'includes :attachments' do
    expect(rendered_relationships[:attachments][:data].size).to eq message.attachments.size
  end
end
