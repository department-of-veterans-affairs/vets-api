# frozen_string_literal: true

require 'rails_helper'

describe DisabilityContentionSerializer, type: :serializer do
  subject { serialize(contention, serializer_class: described_class) }

  let(:contention) { build_stubbed(:disability_contention_arrhythmia) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq contention.id.to_s
  end

  it 'includes :code' do
    expect(attributes['code']).to eq contention.code
  end

  it 'includes :medical_term' do
    expect(attributes['medical_term']).to eq contention.medical_term
  end

  it 'includes :lay_term' do
    expect(attributes['lay_term']).to eq contention.lay_term
  end
end
