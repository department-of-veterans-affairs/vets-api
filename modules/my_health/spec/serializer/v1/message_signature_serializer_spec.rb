# frozen_string_literal: true

require 'rails_helper'

class Signature
  attr_accessor :id, :signature_name, :include_signature, :signature_title

  def initialize(signature_name:, include_signature:, signature_title:)
    @id = nil
    @signature_name = signature_name
    @include_signature = include_signature
    @signature_title = signature_title
  end

  def read_attribute_for_serialization(attr)
    send(attr)
  end
end

describe MyHealth::V1::MessageSignatureSerializer do
  let(:signature) do
    Signature.new(signature_name: 'Test Name', include_signature: false, signature_title: 'Test')
  end

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(signature, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :signature_name' do
    expect(rendered_attributes[:signature_name]).to eq signature.signature_name
  end

  it 'includes :signature_title' do
    expect(rendered_attributes[:signature_title]).to eq signature.signature_title
  end

  it 'includes :include_signature' do
    expect(rendered_attributes[:include_signature]).to eq signature.include_signature
  end
end
