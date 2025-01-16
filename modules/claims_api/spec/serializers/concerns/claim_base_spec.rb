# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/serializers/claims_api/concerns/claim_base'

class DummyBaseSerializer
  include JSONAPI::Serializer
  include ClaimsApi::Concerns::ClaimBase

  def self.object_data(object)
    object.data
  end
end

describe ClaimsApi::Concerns::ClaimBase, type: :concern do
  subject { serialize(claim, serializer_class: DummyBaseSerializer) }

  let(:claim) { build(:evss_claim) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:claim_data) { claim.data }

  it 'includes :date_filed' do
    expect(attributes['date_filed']).to eq Date.strptime(claim.data['date'], '%m/%d/%Y').to_s
  end

  it 'includes :min_est_date' do
    expect(attributes['min_est_date']).to eq Date.strptime(claim.data['min_est_claim_date'], '%m/%d/%Y').to_s
  end

  it 'includes :max_est_date' do
    expect(attributes['max_est_date']).to eq Date.strptime(claim.data['max_est_claim_date'], '%m/%d/%Y').to_s
  end

  it 'includes :development_letter_sent' do
    expected_sent = claim.data['development_letter_sent']&.downcase == 'yes'
    expect(attributes['development_letter_sent']).to eq expected_sent
  end

  it 'includes :decision_letter_sent' do
    expected_sent = claim.data['decision_notification_sent']&.downcase == 'yes'
    expect(attributes['decision_letter_sent']).to eq expected_sent
  end

  context 'when yes/no attributes have invalid values' do
    let(:bad_claim) { build(:evss_claim, :bad_data) }

    it 'logs an error message' do
      message = "Expected key 'development_letter_sent' to be Yes/No. Got 'Test'."
      expect(Rails.logger).to receive(:error).with(message)
      serialize(bad_claim, serializer_class: DummyBaseSerializer)
    end
  end

  it 'includes :documents_needed' do
    expect(attributes['documents_needed']).to be true
  end

  it 'includes :open' do
    expect(attributes['open']).to eq claim.data['claim_complete_date'].blank?
  end

  it 'includes :requested_decision' do
    expect(attributes['requested_decision']).to eq claim.data['waiver5103_submitted']
  end

  it 'includes :claim_type' do
    expect(attributes['claim_type']).to eq claim.data['status_type']
  end

  context 'when :updated_at is nil' do
    it 'does not include :updated_at' do
      expect(attributes).not_to have_key('updated_at')
    end
  end

  context 'when :updated_at is present' do
    let(:claim) { build(:evss_claim, updated_at: Time.current) }

    it 'includes :updated_at' do
      expect_time_eq(attributes['updated_at'], claim.updated_at)
    end
  end
end
