# frozen_string_literal: true

# Test helper for generating claims with all title generator mapping scenarios
module TitleGeneratorTestClaims
  # Returns a complete set of claim attributes matching Lighthouse API structure
  def self.default_claim_attributes
    {
      'claimDate' => '2024-01-01',
      'claimType' => 'Compensation',
      'claimTypeCode' => '400PREDSCHRG',
      'status' => 'CLAIM_RECEIVED',
      'closeDate' => nil,
      'claimPhaseDates' => {
        'phaseChangeDate' => '2024-01-02',
        'phaseType' => 'CLAIM_RECEIVED',
        'currentPhaseBack' => false,
        'latestPhaseType' => 'CLAIM_RECEIVED',
        'previousPhases' => {}
      },
      'contentions' => [
        {
          'name' => 'Sample contention (New)'
        }
      ],
      'decisionLetterSent' => false,
      'developmentLetterSent' => false,
      'documentsNeeded' => false,
      'endProductCode' => '020',
      'evidenceWaiverSubmitted5103' => false,
      'errors' => [],
      'jurisdiction' => 'National Work Queue',
      'lighthouseId' => nil,
      'maxEstClaimDate' => nil,
      'minEstClaimDate' => nil,
      'submitterApplicationCode' => 'VBMS',
      'submitterRoleCode' => 'VET',
      'supportingDocuments' => [],
      'tempJurisdiction' => nil,
      'trackedItems' => [
        {
          'id' => 1,
          'closedDate' => nil,
          'description' => nil,
          'displayName' => 'Medical treatment records',
          'overdue' => false,
          'receivedDate' => nil,
          'requestedDate' => '2024-01-03',
          'status' => 'NEEDED_FROM_YOU',
          'suspenseDate' => '2024-02-03',
          'uploadsAllowed' => true
        }
      ]
    }
  end

  def self.all_test_cases
    [
      # Priority 1: Dependency code (48 total, testing representative samples)
      {
        'id' => 'test-dependency-130DPNDCY',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => 'Dependency',
          'claimTypeCode' => '130DPNDCY',
          'endProductCode' => '130'
        })
      },
      {
        'id' => 'test-dependency-130DPNDCYPMC',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => 'Dependency',
          'claimTypeCode' => '130DPNDCYPMC',
          'endProductCode' => '130'
        })
      },

      # Priority 1: Veterans Pension codes
      {
        'id' => 'test-veterans-pension-180AILP',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => 'Pension',
          'claimTypeCode' => '180AILP',
          'endProductCode' => '180'
        })
      },
      {
        'id' => 'test-veterans-pension-180ORGPEN',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => 'Pension',
          'claimTypeCode' => '180ORGPEN',
          'endProductCode' => '180'
        })
      },

      # Priority 1: Survivors Pension codes
      {
        'id' => 'test-survivors-pension-190ORGDPN',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => 'Pension',
          'claimTypeCode' => '190ORGDPN',
          'endProductCode' => '190'
        })
      },
      {
        'id' => 'test-survivors-pension-190AID',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => 'Pension',
          'claimTypeCode' => '190AID',
          'endProductCode' => '190'
        })
      },

      # Priority 1: DIC codes
      {
        'id' => 'test-dic-290DICEDPMC',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => nil,
          'claimTypeCode' => '290DICEDPMC',
          'endProductCode' => '290'
        })
      },
      {
        'id' => 'test-dic-020SMDICPMC',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => nil,
          'claimTypeCode' => '020SMDICPMC',
          'endProductCode' => '020'
        })
      },

      # Priority 1: Generic Pension codes
      {
        'id' => 'test-generic-pension-150ELECPMC',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => 'Pension',
          'claimTypeCode' => '150ELECPMC',
          'endProductCode' => '150'
        })
      },

      # Priority 1: Null claimType special cases
      {
        'id' => 'test-debt-validation-290DV',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => nil,
          'claimTypeCode' => '290DV',
          'endProductCode' => '290'
        })
      },
      {
        'id' => 'test-debt-validation-pmc-290DVPMC',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => nil,
          'claimTypeCode' => '290DVPMC',
          'endProductCode' => '290'
        })
      },
      {
        'id' => 'test-in-service-death-130ISDDI',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => nil,
          'claimTypeCode' => '130ISDDI',
          'endProductCode' => '130'
        })
      },
      {
        'id' => 'test-dependency-verification-330DVRPMC',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => nil,
          'claimTypeCode' => '330DVRPMC',
          'endProductCode' => '330'
        })
      },

      # Priority 2: Special case transformation (Death)
      {
        'id' => 'test-death-special-case',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => 'Death',
          'claimTypeCode' => nil
        })
      },

      # Priority 3: Default generation (Compensation)
      {
        'id' => 'test-compensation-default',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => 'Compensation',
          'claimTypeCode' => '400PREDSCHRG',
          'endProductCode' => '400'
        })
      },

      # Priority 3: Default generation (Disability)
      {
        'id' => 'test-disability-default',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => 'Disability',
          'claimTypeCode' => nil
        })
      },

      # Priority 3: Default generation (Education)
      {
        'id' => 'test-education-default',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => 'Education',
          'claimTypeCode' => nil
        })
      },

      # Priority 4: Nil fallback (both nil)
      {
        'id' => 'test-nil-fallback-both-nil',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => nil,
          'claimTypeCode' => nil
        })
      },

      # Edge case: Unknown code (not in mapping)
      {
        'id' => 'test-unknown-code',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => 'Education',
          'claimTypeCode' => 'UNKNOWN123'
        })
      },

      # Edge case: Empty strings
      {
        'id' => 'test-empty-strings',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => '',
          'claimTypeCode' => ''
        })
      },

      # Edge case: Mixed case claim type
      {
        'id' => 'test-mixed-case',
        'type' => 'claim',
        'attributes' => default_claim_attributes.merge({
          'claimType' => 'COMPENSATION',
          'claimTypeCode' => nil
        })
      }
    ]
  end

  def self.expected_results
    {
      'test-dependency-130DPNDCY' => {
        display_title: 'Request to add or remove a dependent',
        claim_type_base: 'request to add or remove a dependent'
      },
      'test-dependency-130DPNDCYPMC' => {
        display_title: 'Request to add or remove a dependent',
        claim_type_base: 'request to add or remove a dependent'
      },
      'test-veterans-pension-180AILP' => {
        display_title: 'Claim for Veterans Pension',
        claim_type_base: 'Veterans Pension claim'
      },
      'test-veterans-pension-180ORGPEN' => {
        display_title: 'Claim for Veterans Pension',
        claim_type_base: 'Veterans Pension claim'
      },
      'test-survivors-pension-190ORGDPN' => {
        display_title: 'Claim for Survivors Pension',
        claim_type_base: 'Survivors Pension claim'
      },
      'test-survivors-pension-190AID' => {
        display_title: 'Claim for Survivors Pension',
        claim_type_base: 'Survivors Pension claim'
      },
      'test-dic-290DICEDPMC' => {
        display_title: 'Claim for Dependency and Indemnity Compensation',
        claim_type_base: 'Dependency and Indemnity Compensation claim'
      },
      'test-dic-020SMDICPMC' => {
        display_title: 'Claim for Dependency and Indemnity Compensation',
        claim_type_base: 'Dependency and Indemnity Compensation claim'
      },
      'test-generic-pension-150ELECPMC' => {
        display_title: 'Claim for pension',
        claim_type_base: 'pension claim'
      },
      'test-debt-validation-290DV' => {
        display_title: 'Claim for disability compensation',
        claim_type_base: 'disability compensation claim'
      },
      'test-debt-validation-pmc-290DVPMC' => {
        display_title: 'Claim for disability compensation',
        claim_type_base: 'disability compensation claim'
      },
      'test-in-service-death-130ISDDI' => {
        display_title: 'Claim for disability compensation',
        claim_type_base: 'disability compensation claim'
      },
      'test-dependency-verification-330DVRPMC' => {
        display_title: 'Claim for disability compensation',
        claim_type_base: 'disability compensation claim'
      },
      'test-death-special-case' => {
        display_title: 'Claim for expenses related to death or burial',
        claim_type_base: 'expenses related to death or burial claim'
      },
      'test-compensation-default' => {
        display_title: 'Claim for compensation',
        claim_type_base: 'compensation claim'
      },
      'test-disability-default' => {
        display_title: 'Claim for disability',
        claim_type_base: 'disability claim'
      },
      'test-education-default' => {
        display_title: 'Claim for education',
        claim_type_base: 'education claim'
      },
      'test-nil-fallback-both-nil' => {
        display_title: 'Claim for disability compensation',
        claim_type_base: 'disability compensation claim'
      },
      'test-unknown-code' => {
        display_title: 'Claim for education',
        claim_type_base: 'education claim'
      },
      'test-empty-strings' => {
        display_title: 'Claim for disability compensation',
        claim_type_base: 'disability compensation claim'
      },
      'test-mixed-case' => {
        display_title: 'Claim for compensation',
        claim_type_base: 'compensation claim'
      }
    }
  end
end
