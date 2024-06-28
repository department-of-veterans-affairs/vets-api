# frozen_string_literal: true

require 'rails_helper'

shared_examples '1010 forms attachment serializer' do
  subject { serialize(attachment, serializer_class: described_class) }

  let(:expected) do
    {
      id: '99',
      guid: '75163ba4-01a2-46f1-bdb7-4b1f307f66e4',
      type: resource_name.pluralize
    }
  end
  let(:attachment) do
    build(resource_name.to_sym, id: expected[:id].to_i, guid: expected[:guid])
  end
  let(:data) { JSON.parse(subject)['data'] }

  it 'includes the :id, :type, and :guid in the serialized attachment' do
    expect(data['id']).to eq(expected[:id])
    expect(data['type']).to eq(expected[:type])
    expect(data['attributes']['guid']).to eq(expected[:guid])
  end
end
