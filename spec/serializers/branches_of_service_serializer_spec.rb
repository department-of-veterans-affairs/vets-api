# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BranchesOfServiceSerializer, type: :serializer do
  subject { serialize(branch, serializer_class: described_class) }

  let(:branch) { build :branches_of_service }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes id' do
    expect(data['id']).to eq(branch.id)
  end

  it 'includes the branches_of_service_id' do
    expect(attributes['branches_of_service_id']).to eq(branch.id)
  end

  it 'includes the begin_date' do
    expect(Time.parse(attributes['begin_date']).utc).to eq(branch.begin_date)
  end

  it 'includes the code' do
    expect(attributes['code']).to eq(branch.code)
  end

  it 'includes the end_date' do
    expect(Time.parse(attributes['end_date']).utc).to eq(branch.end_date)
  end

  it 'includes the flat_full_descr' do
    expect(attributes['flat_full_descr']).to eq(branch.flat_full_descr)
  end

  it 'includes the full_descr' do
    expect(attributes['full_descr']).to eq(branch.full_descr)
  end

  it 'includes the short_descr' do
    expect(attributes['short_descr']).to eq(branch.short_descr)
  end

  it 'includes the state_required' do
    expect(attributes['state_required']).to eq(branch.state_required)
  end

  it 'includes the upright_full_descr' do
    expect(attributes['upright_full_descr']).to eq(branch.upright_full_descr)
  end
end
