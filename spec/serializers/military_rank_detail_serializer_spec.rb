# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MilitaryRankDetailSerializer, type: :serializer do
  subject { serialize(military_rank_detail, serializer_class: described_class) }

  let(:military_rank_detail) { build :military_rank_detail }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:links) { data['links'] }

  it 'includes branch_of_service_code as attribute' do
    expect(attributes['branch_of_service_code']).to eq(military_rank_detail.branch_of_service_code)
  end

  it 'includes rank_code as attribute' do
    expect(attributes['rank_code']).to eq(military_rank_detail.rank_code)
  end

  it 'includes rank_descr as attribute' do
    expect(attributes['rank_descr']).to eq(military_rank_detail.rank_descr)
  end
end
