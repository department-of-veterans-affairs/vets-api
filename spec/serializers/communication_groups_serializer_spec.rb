# frozen_string_literal: true

require 'rails_helper'

describe CommunicationGroupsSerializer, type: :serializer do
  subject { serialize(communication_groups, serializer_class: described_class) }

  let(:communication_groups) { { communication_groups: [communication_group] } }
  let(:communication_group) { build_stubbed(:communication_item_group) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :type' do
    expect(data['type']).to eq('hashes')
  end

  it 'includes :communication_groups' do
    expect(attributes['communication_groups'].size).to eq communication_groups[:communication_groups].size
    expect(attributes['communication_groups'].first['id']).to eq communication_groups[:communication_groups].first.id
  end
end
