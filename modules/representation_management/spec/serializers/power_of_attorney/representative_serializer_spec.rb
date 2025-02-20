# frozen_string_literal: true

require 'rails_helper'
require_relative 'shared_base_power_of_attorney'

describe RepresentationManagement::PowerOfAttorney::RepresentativeSerializer, type: :serializer do
  subject { serialize(object, serializer_class: described_class) }

  let(:object) { build_stubbed(:representative) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it_behaves_like 'power_of_attorney'

  it 'includes :type' do
    expect(attributes['type']).to eq 'representative'
  end

  it 'includes :name' do
    expect(attributes['name']).to eq object.full_name
  end

  it 'includes :email' do
    expect(attributes['email']).to eq object.email
  end

  it 'includes :phone' do
    expect(attributes['phone']).to eq object.phone_number
  end

  it 'includes :individual_type' do
    expect(attributes['individual_type']).to eq 'attorney'
  end
end
