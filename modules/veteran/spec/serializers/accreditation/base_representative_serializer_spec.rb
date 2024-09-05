# frozen_string_literal: true

require 'rails_helper'
require_relative 'representative_serializer_shared_spec'

describe Veteran::Accreditation::BaseRepresentativeSerializer, type: :serializer do
  subject { serialize(representative, serializer_class: described_class) }

  before do
    create(:representative, :with_address, representative_id: '123abc')
  end

  let(:representative) do
    Veteran::Service::Representative
      .where(representative_id: '123abc')
      .select('veteran_representatives.*, 4023.36 as distance')
      .first
  end
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  include_examples 'a representative serializer'

  it 'includes :id' do
    expect(data['id']).to eq representative.id
  end

  it 'includes :phone' do
    expect(attributes['phone']).to eq representative.phone
  end
end
