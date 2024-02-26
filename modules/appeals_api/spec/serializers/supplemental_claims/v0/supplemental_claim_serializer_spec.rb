# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::SupplementalClaims::V0::SupplementalClaimSerializer do
  let(:supplemental_claim) { create(:supplemental_claim_v0) }
  let(:rendered_hash) { described_class.new(supplemental_claim).serializable_hash }

  it 'serializes the SC properly' do
    expect(rendered_hash).to eq(
      {
        data: {
          id: supplemental_claim.id,
          type: :supplementalClaim,
          attributes: {
            status: supplemental_claim.status,
            createDate: supplemental_claim.created_at,
            updateDate: supplemental_claim.updated_at
          }
        }
      }
    )
  end

  context 'when SC is in error state' do
    let(:status) { 'error' }
    let(:code) { '999' }
    let(:detail) { 'detail text' }
    let(:supplemental_claim) { create(:supplemental_claim_v0, status:, code:, detail:) }

    it 'serializes the SC properly, including error attributes' do
      expect(rendered_hash).to eq(
        {
          data: {
            id: supplemental_claim.id,
            type: :supplementalClaim,
            attributes: {
              status:,
              createDate: supplemental_claim.created_at,
              updateDate: supplemental_claim.updated_at,
              code:,
              detail:
            }
          }
        }
      )
    end
  end
end
