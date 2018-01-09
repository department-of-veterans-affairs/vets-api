# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BranchesOfServiceSerializer, type: :serializer do
  let(:branch) { build :branches_of_service }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  subject { serialize(branch, serializer_class: described_class) }

  it 'should include id' do
    expect(data['id']).to eq(branch.id)
  end

  it 'should include the branches_of_service_id' do
    expect(attributes['branches_of_service_id']).to eq(branch.id)
  end

  it 'should include the begin_date' do
    expect(Time.parse(attributes['begin_date']).utc).to eq(branch.begin_date)
  end

  it 'should include the code' do
    expect(attributes['code']).to eq(branch.code)
  end

  it 'should include the end_date' do
    expect(Time.parse(attributes['end_date']).utc).to eq(branch.end_date)
  end

  it 'should include the flat_full_descr' do
    expect(attributes['flat_full_descr']).to eq(branch.flat_full_descr)
  end

  it 'should include the full_descr' do
    expect(attributes['full_descr']).to eq(branch.full_descr)
  end

  it 'should include the short_descr' do
    expect(attributes['short_descr']).to eq(branch.short_descr)
  end

  it 'should include the state_required' do
    expect(attributes['state_required']).to eq(branch.state_required)
  end

  it 'should include the upright_full_descr' do
    expect(attributes['upright_full_descr']).to eq(branch.upright_full_descr)
  end
end
