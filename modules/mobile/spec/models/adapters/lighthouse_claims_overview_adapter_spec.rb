# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::Adapters::ClaimsOverview, :aggregate_failures do
  context 'when evidenceWaiverSubmitted5103 is true' do
    let(:waiver_true_claim) do
      [{ 'id' => '600383363',
         'type' => 'claim',
         'attributes' =>
          { 'baseEndProductCode' => '400',
            'claimDate' => '2022-09-27',
            'claimPhaseDates' => { 'phaseChangeDate' => '2022-09-30', 'phaseType' => 'REVIEW_OF_EVIDENCE' },
            'claimType' => 'Compensation',
            'claimTypeCode' => '400PREDSCHRG',
            'closeDate' => nil,
            'decisionLetterSent' => false,
            'developmentLetterSent' => true,
            'documentsNeeded' => true,
            'endProductCode' => '020',
            'evidenceWaiverSubmitted5103' => true,
            'lighthouseId' => nil,
            'status' => 'EVIDENCE_GATHERING_REVIEW_DECISION' } }]
    end

    it 'documentsNeeded is false' do
      output = Mobile::V0::Adapters::ClaimsOverview.new.parse(waiver_true_claim)

      expect(output.first.documents_needed).to be(false)
    end
  end

  context 'when evidenceWaiverSubmitted5103 is false' do
    let(:waiver_false_claim) do
      [{ 'id' => '600383363',
         'type' => 'claim',
         'attributes' =>
          { 'baseEndProductCode' => '400',
            'claimDate' => '2022-09-27',
            'claimPhaseDates' => { 'phaseChangeDate' => '2022-09-30', 'phaseType' => 'REVIEW_OF_EVIDENCE' },
            'claimType' => 'Compensation',
            'claimTypeCode' => '400PREDSCHRG',
            'closeDate' => nil,
            'decisionLetterSent' => false,
            'developmentLetterSent' => true,
            'documentsNeeded' => true,
            'endProductCode' => '020',
            'evidenceWaiverSubmitted5103' => false,
            'lighthouseId' => nil,
            'status' => 'EVIDENCE_GATHERING_REVIEW_DECISION' } }]
    end

    it 'documentsNeeded is derived from documentsNeeded field' do
      output = Mobile::V0::Adapters::ClaimsOverview.new.parse(waiver_false_claim)

      expect(output.first.documents_needed).to be(true)
    end
  end

  context 'using claim title generator' do
    let(:claim) do
      [{ 'id' => '600383363',
         'type' => 'claim',
         'attributes' =>
           { 'baseEndProductCode' => '400',
             'claimDate' => '2022-09-27',
             'claimPhaseDates' => { 'phaseChangeDate' => '2022-09-30', 'phaseType' => 'REVIEW_OF_EVIDENCE' },
             'claimType' => 'Compensation',
             'claimTypeCode' => '400PREDSCHRG',
             'closeDate' => nil,
             'decisionLetterSent' => false,
             'developmentLetterSent' => true,
             'documentsNeeded' => true,
             'endProductCode' => '020',
             'evidenceWaiverSubmitted5103' => false,
             'lighthouseId' => nil,
             'status' => 'EVIDENCE_GATHERING_REVIEW_DECISION' } }]
    end

    it 'displayTitle is derived from claim title generator' do
      allow(Flipper).to receive(:enabled?)
        .with('cst_use_claim_title_generator_mobile').and_return(true)
      output = Mobile::V0::Adapters::ClaimsOverview.new.parse(claim)

      expect(output.first.display_title).to eq('Claim for compensation')
    end

    it 'displayTitle is not derived from claim title generator' do
      allow(Flipper).to receive(:enabled?)
        .with('cst_use_claim_title_generator_mobile').and_return(false)
      output = Mobile::V0::Adapters::ClaimsOverview.new.parse(claim)

      expect(output.first.display_title).to eq('Compensation')
    end
  end
end
