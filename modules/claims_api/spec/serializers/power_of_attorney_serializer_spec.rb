# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneySerializer do
  let(:poa_submission) { build(:power_of_attorney, status: ClaimsApi::PowerOfAttorney::UPLOADED) }
  let(:rendered_hash) { described_class.new(poa_submission).serializable_hash }

  it 'includes :date_request_accepted' do
    expect(rendered_hash[:date_request_accepted]).to eq poa_submission.date_request_accepted
  end

  it 'includes :representative' do
    expect(rendered_hash[:representative]).to eq poa_submission.representative
  end

  it 'includes :previous_poa' do
    expect(rendered_hash[:previous_poa]).to eq poa_submission.previous_poa
  end

  context 'when a POA submission has a status property of "uploaded"' do
    it 'transforms status to "updated"' do
      expect(poa_submission[:status]).to eq(ClaimsApi::PowerOfAttorney::UPLOADED)
      expect(rendered_hash[:status]).to eq(ClaimsApi::PowerOfAttorney::UPDATED)
    end
  end

  context 'when a POA submission does not have a status property of "uploaded"' do

    let(:submitted_poa_submission) { build(:power_of_attorney) }
    let(:submitted_rendered_hash) { described_class.new(submitted_poa_submission).serializable_hash }

    it 'includes :status from poa_submission' do
      expect(submitted_rendered_hash[:status]).to eq(submitted_poa_submission.status)
    end
  end
end
