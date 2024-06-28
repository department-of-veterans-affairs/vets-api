# frozen_string_literal: true

require 'rails_helper'

describe Veteran::Service::RepresentativeSerializer, type: :serializer do
  subject { serialize(representative, serializer_class: described_class) }

  let(:representative) { build_stubbed(:representative) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :first_name' do
    expect(attributes['first_name']).to eq representative.first_name
  end

  it 'includes :last_name' do
    expect(attributes['last_name']).to eq representative.last_name
  end

  it 'includes :poa_codes' do
    expect(attributes['poa_codes']).to eq representative.poa_codes
  end
end
