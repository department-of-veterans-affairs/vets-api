# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MessageSerializer, type: :serializer do
  subject { serialize(message, serializer_class: described_class) }

  let(:message) { build_stubbed(:message, :with_attachments) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:relationships) { data['relationships'] }

  it 'includes :attachments' do
    expect(relationships['attachments']['data'].size).to eq message.attachments.size
  end

end
