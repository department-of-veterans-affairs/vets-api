# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InProgressFormSerializer do
  subject { serialize(in_progress_form, serializer_class: described_class) }

  let(:in_progress_form) { build(:in_progress_form) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:metadata) { attributes['metadata'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :type' do
    expect(data['type']).to eq 'in_progress_forms'
  end

  it 'includes :createdAt' do
    expect(attributes['createdAt']).to eq in_progress_form.created_at
  end

  it 'includes :metadata' do
    expect(metadata).to eq in_progress_form.metadata
  end

  context 'with nested metadata' do
    it 'keep the original case of metadata' do
      expect(metadata).to eq in_progress_form.metadata
      expect(metadata.keys).to eq(in_progress_form.metadata.keys)
    end
  end
end
