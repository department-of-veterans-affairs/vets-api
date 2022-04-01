# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PowerOfAttorneySerializer do
  let(:poa_submission) { create(:power_of_attorney, status: ClaimsApi::PowerOfAttorney::UPLOADED) }
  let(:rendered_hash) { described_class.new(poa_submission).serializable_hash }

  context 'when a POA submission has a status property of "uploaded"' do
    it 'transforms status to "updated"' do
      expect(poa_submission[:status]).to eq(ClaimsApi::PowerOfAttorney::UPLOADED)
      expect(rendered_hash[:status]).to eq(ClaimsApi::PowerOfAttorney::UPDATED)
    end
  end
end
