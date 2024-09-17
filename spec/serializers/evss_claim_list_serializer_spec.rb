# frozen_string_literal: true

require 'rails_helper'
require_relative 'shared_examples_evss_claim_spec'

RSpec.describe EVSSClaimListSerializer, type: :serializer do
  subject { serialize(evss_claim, serializer_class: described_class) }

  let(:evss_claim) { build(:evss_claim) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:object_data) { evss_claim.list_data }
  let(:attributes) { data['attributes'] }

  it_behaves_like 'shared_evss_claim'

  it 'includes :phase' do
    phase = evss_claim.list_data['status']&.downcase
    expect(attributes['phase']).to eq EVSSClaimBaseHelper::PHASE_MAPPING[phase]
  end
end
