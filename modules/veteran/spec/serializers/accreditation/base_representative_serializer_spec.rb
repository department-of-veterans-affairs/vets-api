# frozen_string_literal: true

require 'rails_helper'
require_relative 'representative_serializer_shared_spec'

describe Veteran::Accreditation::BaseRepresentativeSerializer, type: :serializer do
  before do
    Veteran::Service::Representative.define_method(:distance) { }
    allow_any_instance_of(Veteran::Service::Representative).to receive(:distance).and_return(4023.36)
  end

  subject { serialize(representative, serializer_class: described_class) }

  let(:representative) { create(:representative, :with_address) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  include_examples 'a representative serializer'

  it 'includes :phone' do
    expect(attributes['phone']).to eq representative.phone
  end
end
