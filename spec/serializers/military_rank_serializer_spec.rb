# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MilitaryRankSerializer, type: :serializer do
  let(:military_rank_detail) { build :military_rank_detail }
  let(:military_rank) { build :military_rank, military_rank_detail: military_rank_detail }
  let(:data) { JSON.parse(subject)['data'] }
  let(:id) { JSON.parse(subject).keys }
  let(:attributes) { data['attributes'] }

  subject { serialize(military_rank, serializer_class: described_class) }

  it 'should include branch_of_service_cd as attribute' do
    expect(attributes['branch_of_service_cd']).to eq(military_rank.branch_of_service_cd)
  end

  it 'should include activated_one_date as attribute' do
    expect(Time.parse(attributes['activated_one_date']).utc).to eq(military_rank.activated_one_date)
  end

  it 'should include activated_two_date as attribute' do
    expect(Time.parse(attributes['activated_two_date']).utc).to eq(military_rank.activated_two_date)
  end

  it 'should include activated_three_date as attribute' do
    expect(Time.parse(attributes['activated_three_date']).utc).to eq(military_rank.activated_three_date)
  end

  it 'should include deactivated_one_date as attribute' do
    expect(Time.parse(attributes['deactivated_one_date']).utc).to eq(military_rank.deactivated_one_date)
  end

  it 'should include deactivated_two_date as attribute' do
    expect(Time.parse(attributes['deactivated_two_date']).utc).to eq(military_rank.deactivated_two_date)
  end

  it 'should include deactivated_three_date as attribute' do
    expect(Time.parse(attributes['deactivated_three_date']).utc).to eq(military_rank.deactivated_three_date)
  end

  it 'should include officer_ind as attribute' do
    expect(attributes['officer_ind']).to eq(military_rank.officer_ind)
  end
end
