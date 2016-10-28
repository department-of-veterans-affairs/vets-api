# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DisabilityClaimDetailSerializer, type: :serializer do
  let(:disability_claim) { create(:disability_claim) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  subject { serialize(disability_claim, serializer_class: DisabilityClaimDetailSerializer) }

  it 'should include id' do
    expect(data['id']).to eq(disability_claim.id.to_s)
  end

  it 'should not include raw HTML' do
    expect(attributes.to_json.to_s.include?('<')).to be(false)
  end
end
