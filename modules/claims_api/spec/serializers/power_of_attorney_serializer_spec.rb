# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneySerializer do
  let(:poa_submission) { build(:power_of_attorney, status: ClaimsApi::PowerOfAttorney::UPLOADED) }
  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(poa_submission, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :date_request_accepted' do
    expect(rendered_attributes[:date_request_accepted]).to eq poa_submission.date_request_accepted
  end

  it 'includes :representative' do
    expect(rendered_attributes[:representative]).to eq poa_submission.representative
  end

  it 'includes :previous_poa' do
    expect(rendered_attributes[:previous_poa]).to eq poa_submission.previous_poa
  end

  context 'when a POA submission has a status property of "uploaded"' do
    it 'transforms status to "updated"' do
      expect(poa_submission[:status]).to eq(ClaimsApi::PowerOfAttorney::UPLOADED)
      expect(rendered_attributes[:status]).to eq(ClaimsApi::PowerOfAttorney::UPDATED)
    end
  end

  context 'when a POA submission does not have a status property of "uploaded"' do
    let(:submitted_poa_submission) { build(:power_of_attorney) }
    let(:submitted_rendered_hash) do
      ActiveModelSerializers::SerializableResource.new(submitted_poa_submission,
                                                       { serializer: described_class }).as_json
    end
    let(:submitted_rendered_attributes) { submitted_rendered_hash[:data][:attributes] }

    it 'includes :status from poa_submission' do
      expect(submitted_rendered_attributes[:status]).to eq(submitted_poa_submission.status)
    end
  end
end
