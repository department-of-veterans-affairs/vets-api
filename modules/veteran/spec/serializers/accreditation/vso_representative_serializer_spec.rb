# frozen_string_literal: true

require 'rails_helper'
require_relative 'representative_serializer_shared_spec'

describe Veteran::Accreditation::VSORepresentativeSerializer, type: :serializer do

  before do
    Veteran::Service::Representative.define_method(:distance) { }
    allow_any_instance_of(Veteran::Service::Representative).to receive(:distance).and_return(4023.36)

    Veteran::Service::Representative.define_method(:organization_names) { }
    allow_any_instance_of(Veteran::Service::Representative).to receive(:organization_names).and_return(['org1_name', 'org2_name', 'org3_name'])
  end

  subject { serialize(representative, serializer_class: described_class) }

  let(:representative) { create(:representative, :with_address) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  include_examples 'a representative serializer'

  it 'includes :organization_names' do
    expect(attributes['organization_names']).to eq(%w[org1_name org2_name org3_name])
  end

  it 'includes :phone' do
    expect(attributes['phone']).to eq representative.phone_number
  end
end
