# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SchedulingPreferencesSerializer, type: :serializer do
  subject { serialize(scheduling_preferences, serializer_class: described_class) }

  let(:scheduling_preferences) do
    {
      preferences: [
        { item_id: 1, option_ids: [5] },
        { item_id: 2, option_ids: [7, 11] }
      ]
    }
  end

  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :type' do
    expect(data['type']).to eq('scheduling_preferences')
  end

  it 'includes :preferences' do
    expected_preferences = [
      { 'item_id' => 1, 'option_ids' => [5] },
      { 'item_id' => 2, 'option_ids' => [7, 11] }
    ]
    expect(attributes['preferences']).to eq(expected_preferences)
  end

  it 'serializes preferences array structure' do
    preferences = attributes['preferences']

    expect(preferences).to be_an(Array)
    expect(preferences.length).to eq(2)

    first_preference = preferences.first
    expect(first_preference['item_id']).to eq(1)
    expect(first_preference['option_ids']).to eq([5])

    second_preference = preferences.last
    expect(second_preference['item_id']).to eq(2)
    expect(second_preference['option_ids']).to eq([7, 11])
  end

  context 'when preferences array is empty' do
    let(:scheduling_preferences) { { preferences: [] } }

    it 'includes empty preferences array' do
      expect(attributes['preferences']).to eq([])
    end
  end
end
