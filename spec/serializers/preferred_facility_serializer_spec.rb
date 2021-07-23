# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PreferredFacilitySerializer do
  subject { serialize(create(:preferred_facility), serializer_class: described_class) }

  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'returns serialized facility_code data' do
    expect(attributes['facility_code']).to eq('983')
  end
end
