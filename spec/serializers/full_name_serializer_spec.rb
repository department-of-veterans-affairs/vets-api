# frozen_string_literal: true

require 'rails_helper'

describe FullNameSerializer, type: :serializer do
  subject { serialize(full_name, serializer_class: described_class) }

  let(:full_name) { { first: 'John', middle: 'Steven', last: 'Doe', suffix: 'Jr' } }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :first' do
    expect(attributes['first']).to eq full_name[:first]
  end

  it 'includes :middle' do
    expect(attributes['middle']).to eq full_name[:middle]
  end

  it 'includes :last' do
    expect(attributes['last']).to eq full_name[:last]
  end

  it 'includes :suffix' do
    expect(attributes['suffix']).to eq full_name[:suffix]
  end
end
