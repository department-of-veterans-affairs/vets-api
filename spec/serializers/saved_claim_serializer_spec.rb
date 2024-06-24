# frozen_string_literal: true

require 'rails_helper'

describe SavedClaimSerializer, type: :serializer do
  subject { serialize(saved_claim, serializer_class: described_class) }

  let(:saved_claim) { build_stubbed(:burial_claim) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq saved_claim.id.to_s
  end

  it 'includes :submitted_at' do
    expect_time_eq(attributes['submitted_at'], saved_claim.submitted_at)
  end

  it 'includes :regional_office' do
    expect(attributes['regional_office']).to eq saved_claim.regional_office
  end

  it 'includes :confirmation_number' do
    expect(attributes['confirmation_number']).to eq saved_claim.confirmation_number
  end

  it 'includes :guid' do
    expect(attributes['guid']).to eq saved_claim.guid
  end

  it 'includes :form' do
    expect(attributes['form']).to eq saved_claim.form_id
  end
end
