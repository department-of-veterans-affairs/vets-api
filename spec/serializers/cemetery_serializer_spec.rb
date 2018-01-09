# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CemeterySerializer, type: :serializer do
  let(:cemetery) { build :cemetery }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  subject { serialize(cemetery, serializer_class: described_class) }

  it 'should include id' do
    expect(data['id']).to eq(cemetery.id)
  end

  it 'should include the cemetery_id' do
    expect(attributes['cemetery_id']).to eq(cemetery.id)
  end

  it 'should include the num' do
    expect(attributes['num']).to eq(cemetery.num)
  end

  it 'should include the cemetery_type' do
    expect(attributes['cemetery_type']).to eq(cemetery.cemetery_type)
  end
end
