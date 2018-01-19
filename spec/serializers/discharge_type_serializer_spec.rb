# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DischargeTypeSerializer, type: :serializer do
  let(:discharge_type) { build :discharge_type }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  subject { serialize(discharge_type, serializer_class: described_class) }

  it 'should include id' do
    expect(data['id'].to_i).to eq(discharge_type.id)
  end

  it 'should include the discharge_type_id' do
    expect(attributes['discharge_type_id']).to eq(discharge_type.id)
  end

  it 'should include the description' do
    expect(attributes['description']).to eq(discharge_type.description)
  end
end
