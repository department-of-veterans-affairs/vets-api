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

  describe '#as_json' do
    it 'returns proper JSON API structure' do
      claim = described_class.new(valid_params)
      json = claim.as_json

      # Verify top-level structure
      expect(json[:id]).to eq('555555555')
      expect(json[:type]).to eq('claim')
      expect(json[:attributes]).to be_a(Hash)

      # Verify all attributes are present
      attrs = json[:attributes]
      expect(attrs['baseEndProductCode']).to eq('400')
      expect(attrs['claimDate']).to eq('2017-05-02')
      expect(attrs['claimType']).to eq('Compensation')
      expect(attrs['claimTypeCode']).to eq('400PREDSCHRG')
      expect(attrs['closeDate']).to eq('2017-10-18')
      expect(attrs['decisionLetterSent']).to be(false)
      expect(attrs['developmentLetterSent']).to be(false)
      expect(attrs['documentsNeeded']).to be(false)
      expect(attrs['endProductCode']).to eq('404')
      expect(attrs['evidenceWaiverSubmitted5103']).to be(false)
      expect(attrs['status']).to eq('COMPLETE')

      # Verify nested claimPhaseDates
      expect(attrs['claimPhaseDates']).to be_a(Hash)
      expect(attrs['claimPhaseDates']['phaseChangeDate']).to eq('2017-10-18')
      expect(attrs['claimPhaseDates']['phaseType']).to eq('COMPLETE')

      # Verify nil attributes are excluded
      expect(attrs).not_to have_key('lighthouseId')
    end
  end

  describe 'backward compatibility with Lighthouse format' do
    it 'produces output matching Lighthouse fixture format' do
      claim = described_class.new(valid_params)
      json = claim.as_json

      # This should match the structure in spec/fixtures/lighthouse_claim/claim.json
      expected_structure = {
        id: '555555555',
        type: 'claim',
        attributes: {
          'baseEndProductCode' => '400',
          'claimDate' => '2017-05-02',
          'claimPhaseDates' => { 'phaseChangeDate' => '2017-10-18', 'phaseType' => 'COMPLETE' },
          'claimType' => 'Compensation',
          'claimTypeCode' => '400PREDSCHRG',
          'closeDate' => '2017-10-18',
          'decisionLetterSent' => false,
          'developmentLetterSent' => false,
          'documentsNeeded' => false,
          'endProductCode' => '404',
          'evidenceWaiverSubmitted5103' => false,
          'status' => 'COMPLETE'
        }
      }

      expect(json).to eq(expected_structure)
    end
  end
end
