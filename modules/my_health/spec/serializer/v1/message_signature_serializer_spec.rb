# frozen_string_literal: true

require 'rails_helper'

describe MyHealth::V1::MessageSignatureSerializer, type: :serializer do
  subject { serialize(signature, serializer_class: described_class) }

  let(:signature) do
    {
      signature_name: 'test-api Name',
      include_signature: true,
      signature_title: 'test-api title'
    }
  end
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :signature_name' do
    expect(attributes['signature_name']).to eq signature[:signature_name]
  end

  it 'includes :signature_title' do
    expect(attributes['signature_title']).to eq signature[:signature_title]
  end

  it 'includes :include_signature' do
    expect(attributes['include_signature']).to eq signature[:include_signature]
  end

  context 'when include_signature is false but signature_name and signature_title are non-blank' do
    let(:signature) do
      {
        signature_name: 'test-api Name',
        include_signature: false,
        signature_title: 'test-api title'
      }
    end

    it 'returns true for :include_signature' do
      expect(attributes['include_signature']).to be true
    end
  end
end
