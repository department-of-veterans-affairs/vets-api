# frozen_string_literal: true
require 'rails_helper'

RSpec.describe BurialStateSerializer, type: :serializer do
  let(:burial_state) do
    BurialState.new(code: 'AA', first_five_zip: '11111', last_five_zip: '22222', lower_indicator: 'Y', name: 'AAAA')
  end

  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  subject { serialize(burial_state, serializer_class: described_class) }

  it 'should include id' do
    expect(data['id']).to eq(burial_state.id)
  end

  it 'should include the burial_state_id' do
    expect(attributes['burial_state_id']).to eq(burial_state.id)
  end

  it 'should include the code' do
    expect(attributes['code']).to eq(burial_state.code)
  end

  it 'should include the first_five_zip' do
    expect(attributes['first_five_zip']).to eq(burial_state.first_five_zip)
  end

  it 'should include the last_five_zip' do
    expect(attributes['last_five_zip']).to eq(burial_state.last_five_zip)
  end

  it 'should include the lower_indicator' do
    expect(attributes['lower_indicator']).to eq(burial_state.lower_indicator)
  end

  it 'should include the name' do
    expect(attributes['name']).to eq(burial_state.name)
  end
end
