# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSSClaimListSerializer, type: :serializer do
  subject { serialize(evss_claim, serializer_class: described_class) }

  let(:evss_claim) { build(:evss_claim) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :phase' do
    phase = evss_claim.list_data['status']&.downcase
    expect(attributes['phase']).to eq PHASE_MAPPING[phase]
  end
end
