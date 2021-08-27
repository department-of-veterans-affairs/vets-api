# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::AttachmentSerializer do
  subject { serialize(attachment, serializer_class: described_class) }

  let(:expected) do
    {
      id: '99',
      guid: '75163ba4-01a2-46f1-bdb7-4b1f307f66e4',
      type: 'form1010cg_attachments'
    }
  end

  let(:attachment) do
    build(:form1010cg_attachment, id: expected[:id].to_i, guid: expected[:guid])
  end

  let(:data) { JSON.parse(subject)['data'] }

  it 'includes id' do
    expect(data['id']).to eq(expected[:id])
  end

  it 'includes type' do
    expect(data['type']).to eq(expected[:type])
  end

  it 'includes the guid' do
    expect(data['attributes']['guid']).to eq(expected[:guid])
  end
end
