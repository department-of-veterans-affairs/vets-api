# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneySerializer, type: :serializer do
  include SerializerSpecHelper

  subject { serialize(poa_submission, serializer_class: described_class) }

  let(:poa_submission) { build(:power_of_attorney, status: ClaimsApi::PowerOfAttorney::UPLOADED) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq poa_submission.id.to_s
  end

  it 'includes :date_request_accepted' do
    expect(attributes['date_request_accepted']).to eq poa_submission.date_request_accepted
  end

  it 'includes :representative' do
    expect(attributes['representative']).to eq poa_submission.representative
  end

  it 'includes :previous_poa' do
    expect(attributes['previous_poa']).to eq poa_submission.previous_poa
  end

  context 'when a POA submission has a status property of "uploaded"' do
    it 'transforms status to "updated"' do
      expect(poa_submission[:status]).to eq(ClaimsApi::PowerOfAttorney::UPLOADED)
      expect(attributes['status']).to eq(ClaimsApi::PowerOfAttorney::UPDATED)
    end
  end

  context 'when a POA submission does not have a status property of "uploaded"' do
    let(:poa_submission) { build(:power_of_attorney) }

    it 'includes :status from poa_submission' do
      expect(poa_submission['status']).to eq(poa_submission.status)
    end
  end
end
