# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::VerificationSerializer, type: :serializer do
  subject { serialize(verification, serializer_class: described_class) }

  let(:verification) { build_stubbed(:vye_verification) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:relationships) { data['relationships'] }

  it 'includes :award_id' do
    expect(attributes['award_id']).to eq verification.award_id
  end

  it 'includes :act_begin' do
    expect(attributes['act_begin']).to eq verification.act_begin
  end

  it 'includes :act_end' do
    expect(attributes['act_end']).to eq verification.act_end
  end

  it 'includes :transact_date' do
    expect(attributes['transact_date']).to eq verification.transact_date.to_s
  end

  it 'includes :monthly_rate' do
    expect(attributes['monthly_rate']).to eq verification.monthly_rate
  end

  it 'includes :number_hours' do
    expect(attributes['number_hours']).to eq verification.number_hours
  end

  it 'includes :source_ind' do
    expect(attributes['source_ind']).to eq verification.source_ind
  end
end
