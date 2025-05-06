# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CemeterySerializer do
  subject { serialize(cemetery, serializer_class: described_class) }

  let(:cemetery) { build(:cemetery) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq(cemetery.id)
  end

  it 'includes :type' do
    expect(data['type']).to eq('preneeds_cemeteries')
  end

  it 'includes :cemetery_id' do
    expect(attributes['cemetery_id']).to eq(cemetery.id)
  end

  it 'includes :num' do
    expect(attributes['num']).to eq(cemetery.num)
  end

  it 'includes :cemetery_type' do
    expect(attributes['cemetery_type']).to eq(cemetery.cemetery_type)
  end
end
