# frozen_string_literal: true

require 'rails_helper'

describe RepresentationManagement::PowerOfAttorneyRequestSerializer, type: :serializer do
  subject { serialize(example, serializer_class: described_class) }

  let(:example) do
    OpenStruct.new(id: 'efd18b43-4421-4539-941a-7397fadfe5dc',
                   created_at: '2025-02-21T00:00:00.000000000Z'.to_datetime,
                   expires_at: '2025-04-22T00:00:00.000000000Z'.to_datetime)
  end
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq example.id
  end

  it 'includes :type' do
    expect(data['type']).to eq 'power_of_attorney_request'
  end

  it 'includes :created_at' do
    expect_time_eq(attributes['created_at'], example.created_at)
  end

  it 'includes :expires_at' do
    expect_time_eq(attributes['expires_at'], example.expires_at)
  end
end
