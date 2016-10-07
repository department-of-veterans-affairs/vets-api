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

  KEYS = %w( evss_id date_filed min_est_date max_est_date
             phase_change_date open waiver_submitted contention_list
             va_representative events_timeline development_letter_sent
             decision_letter_sent documents_needed successful_sync updated_at
             phase).freeze

  it "shouldn't include any extra attributes" do
    expect(attributes.keys.sort).to eq(KEYS.sort)
  end

  it 'should sort the events_timeline' do
    sorted = attributes['events_timeline'].sort_by { |item| item['date'] }.reverse
    expect(attributes['events_timeline']).to eq(sorted)
  end
end
