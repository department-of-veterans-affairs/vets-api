# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe Vye::VerificationSerializer, type: :serializer do
  subject { described_class.new(verification).to_json }

  let(:verification) { build_stubbed(:vye_verification) }
  let(:data) { JSON.parse(subject) }

  it 'includes :award_id' do
    expect(data['award_id']).to eq verification.award_id
  end

  it 'includes :act_begin' do
    expect(data['act_begin']).to eq verification.act_begin
  end

  it 'includes :act_end' do
    expect(data['act_end']).to eq verification.act_end
  end

  it 'includes :transact_date' do
    expect(data['transact_date']).to eq verification.transact_date.to_s
  end

  it 'includes :monthly_rate' do
    expect(data['monthly_rate']).to eq verification.monthly_rate
  end

  it 'includes :number_hours' do
    expect(data['number_hours']).to eq verification.number_hours
  end

  it 'includes :source_ind' do
    expect(data['source_ind']).to eq verification.source_ind
  end
end
