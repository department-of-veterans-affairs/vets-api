# frozen_string_literal: true

require 'rails_helper'
require 'benefits_claims/responses/claim_response'

RSpec.describe BenefitsClaims::Responses::ClaimResponse do
  let(:claim_phase_dates) do
    BenefitsClaims::Responses::ClaimPhaseDates.new(
      phase_change_date: '2017-10-18',
      phase_type: 'COMPLETE'
    )
  end

  let(:valid_params) do
    {
      id: '555555555',
      type: 'claim',
      base_end_product_code: '400',
      claim_date: '2017-05-02',
      claim_phase_dates:,
      claim_type: 'Compensation',
      claim_type_code: '400PREDSCHRG',
      close_date: '2017-10-18',
      decision_letter_sent: false,
      development_letter_sent: false,
      documents_needed: false,
      end_product_code: '404',
      evidence_waiver_submitted5103: false,
      lighthouse_id: nil,
      status: 'COMPLETE'
    }
  end

  describe '#initialize' do
    it 'creates a claim response with valid attributes' do
      claim = described_class.new(valid_params)

      expect(claim.id).to eq('555555555')
      expect(claim.type).to eq('claim')
      expect(claim.base_end_product_code).to eq('400')
      expect(claim.claim_date).to eq('2017-05-02')
      expect(claim.claim_phase_dates).to be_a(BenefitsClaims::Responses::ClaimPhaseDates)
      expect(claim.claim_phase_dates.phase_change_date).to eq('2017-10-18')
      expect(claim.claim_phase_dates.phase_type).to eq('COMPLETE')
      expect(claim.claim_type).to eq('Compensation')
      expect(claim.claim_type_code).to eq('400PREDSCHRG')
      expect(claim.close_date).to eq('2017-10-18')
      expect(claim.decision_letter_sent).to be(false)
      expect(claim.development_letter_sent).to be(false)
      expect(claim.documents_needed).to be(false)
      expect(claim.end_product_code).to eq('404')
      expect(claim.evidence_waiver_submitted5103).to be(false)
      expect(claim.lighthouse_id).to be_nil
      expect(claim.status).to eq('COMPLETE')
    end

    it 'defaults type to "claim" if not provided' do
      params = valid_params.except(:type)
      claim = described_class.new(params)

      expect(claim.type).to eq('claim')
    end
  end
end
