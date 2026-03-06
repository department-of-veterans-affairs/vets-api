# frozen_string_literal: true

require 'rails_helper'
require 'survivors_benefits/structured_data/section_04'

RSpec.describe SurvivorsBenefits::StructuredData::Section04 do
  describe '#build_section4' do
    it 'calls marital_info_data' do
      form = {
        'pregnantWithVeteran' => true,
        'liveContinuouslyWithVeteran' => true,
        'separationDueToAssignedReasons' => true,
        'marriageType' => 'ceremonial'
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect(service).to receive(:marital_info_data)
      service.build_section4
    end

    it 'calls merge_veteran_separation_fields' do
      form = { 'marriedToVeteranAtTimeOfDeath' => true }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect(service).to receive(:merge_veteran_separation_fields)
      service.build_section4
    end

    it 'calls merge_claimant_remarriage_fields' do
      form = { 'claimantRemarried' => true }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect(service).to receive(:merge_claimant_remarriage_fields)
      service.build_section4
    end

    it 'merges marital information fields' do
      form = {
        'validMarriage' => true,
        'childWithVeteran' => true,
        'pregnantWithVeteran' => true,
        'livedContinuouslyWithVeteran' => true,
        'separationDueToAssignedReasons' => true,
        'marriageType' => 'ceremonial',
        'marriageDates' => { 'from' => '2000-01-01', 'to' => '2010-01-01' },
        'placeOfMarriage' => 'Anytown, USA',
        'placeOfMarriageTermination' => 'Othertown, USA',
        'marriageTypeExplanation' => 'We had a ceremonial wedding.',
        'separationExplanation' => 'We separated due to financial issues.'
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.build_section4
      expect(service.fields).to include(
        'AWARE_OF_MARRIAGE_VALIDITY_YES' => true,
        'AWARE_OF_MARRIAGE_VALIDITY_NO' => false,
        'CHILD_DURING_MARRIAGE_YES' => true,
        'CHILD_DURING_MARRIAGE_NO' => false,
        'EXPECTING_BIRTH_VET_CHILD_YES' => true,
        'EXPECTING_BIRTH_VET_CHILD_NO' => false,
        'LIVE_WITH_VET_TILL_DEATH_YES' => true,
        'LIVE_WITH_VET_TILL_DEATH_NO' => false,
        'MARITAL_DISCORD_SEPARATION_Y' => true,
        'MARITAL_DISCORD_SEPARATION_N' => false,
        'CB_CL_MARR_1_TYPE_CEREMONIAL' => true,
        'CB_CL_MARR_1_TYPE_OTHER' => false,
        'VET_CLAIMANT_MARRIAGE_1_DATE' => '01/01/2000',
        'VET_CLAIMANT_MARRIAGE_1_DATE_ENDED' => '01/01/2010',
        'VET_CLAIMANT_MARRIAGE_1_PLACE' => 'Anytown, USA',
        'VET_CLAIMANT_MARRIAGE_1_PLACE_ENDED' => 'Othertown, USA',
        'CL_MARR_1_TYPE_OTHEREXPLAIN' => 'We had a ceremonial wedding.',
        'MARITAL_DISCORD_SEPARATION_EXP' => 'We separated due to financial issues.'
      )
    end
  end

  describe '#marital_info_data' do
    it 'extracts marital information from the form' do
      form = {
        'pregnantWithVeteran' => true,
        'livedContinuouslyWithVeteran' => true,
        'separationDueToAssignedReasons' => true,
        'marriageType' => 'ceremonial'
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect(service.marital_info_data).to eq([true, true, true, 'ceremonial'])
    end
  end

  describe '#merge_veteran_separation_fields' do
    describe 'when married to veteran at time of death' do
      it 'merges separation fields with death as reason' do
        form = { 'marriedToVeteranAtTimeOfDeath' => true }
        service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
        service.merge_veteran_separation_fields
        expect(service.fields).to include(
          'MARRIED_WHILE_VET_DEATH_Y' => true,
          'MARRIED_WHILE_VET_DEATH_N' => false,
          'CB_MARR_TO_VET_ENDED_DEATH' => true,
          'CB_MARR_TO_VET_ENDED_DIVORCE' => false,
          'CB_MARR_TO_VET_ENDED_OTHER' => false
        )
      end
    end

    describe 'when not married to veteran at time of death' do
      it 'merges separation fields with death as reason' do
        form = {
          'marriedToVeteranAtTimeOfDeath' => false,
          'howMarriageEnded' => 'divorce'

        }
        service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
        service.merge_veteran_separation_fields
        expect(service.fields).to include(
          'MARRIED_WHILE_VET_DEATH_Y' => false,
          'MARRIED_WHILE_VET_DEATH_N' => true,
          'CB_MARR_TO_VET_ENDED_DEATH' => false,
          'CB_MARR_TO_VET_ENDED_DIVORCE' => true,
          'CB_MARR_TO_VET_ENDED_OTHER' => false
        )
      end
    end

    describe 'when marriage ended for other reason' do
      it 'merges separation fields with other as reason and includes explanation' do
        form = {
          'marriedToVeteranAtTimeOfDeath' => false,
          'howMarriageEnded' => 'other',
          'howMarriageEndedExplanation' => 'We separated due to financial issues.'
        }
        service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
        service.merge_veteran_separation_fields
        expect(service.fields).to include(
          'MARRIED_WHILE_VET_DEATH_Y' => false,
          'MARRIED_WHILE_VET_DEATH_N' => true,
          'CB_MARR_TO_VET_ENDED_DEATH' => false,
          'CB_MARR_TO_VET_ENDED_DIVORCE' => false,
          'CB_MARR_TO_VET_ENDED_OTHER' => true,
          'MARR_TO_VET_ENDED_OTHEREXPLAIN' => 'We separated due to financial issues.'
        )
      end
    end
  end

  describe '#merge_claimant_remarriage_fields' do
    it 'calls expand_and_merge_remarriage_end_cause' do
      form = { 'remarriedAfterVeteralDeath' => true, 'remarriageEndCause' => 'death' }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      expect(service).to receive(:expand_and_merge_remarriage_end_cause).with(true, 'death')
      service.merge_claimant_remarriage_fields
    end

    describe 'when remarriage end cause is not other' do
      it 'merges remarriage fields' do
        form = {
          'remarriedAfterVeteralDeath' => true,
          'remarriageEndCause' => 'divorce',
          'claimantHasAdditionalMarriages' => true,
          'remarriageDates' => { 'from' => '2000-01-01', 'to' => '2010-01-01' }
        }
        service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
        service.merge_claimant_remarriage_fields
        expect(service.fields).to include(
          'REMARRIED_AFTER_VET_DEATH_YES' => true,
          'REMARRIED_AFTER_VET_DEATH_NO' => false,
          'ADDITIONAL_MARRIAGES_Y' => true,
          'ADDITIONAL_MARRIAGES_N' => false,
          'CLAIMANT_REMARRIAGE_1_DATE' => '01/01/2000',
          'CLAIMANT_REMARRIAGE_1_DATE_ENDED' => '01/01/2010',
          'REMARRIAGE_OTHER_EXPLANATION' => nil,
          'CB_REMARRIAGE_END_BY_DEATH' => false,
          'CB_REMARRIAGE_END_BY_DIVORCE' => true,
          'CB_MARRIAGE_DID_NOT_END' => false,
          'CB_REMARRIAGE_END_BY_OTHER' => false
        )
      end
    end

    describe 'when remarriage end cause is other' do
      it 'merges remarriage fields with other explanation' do
        form = {
          'remarriedAfterVeteralDeath' => true,
          'remarriageEndCause' => 'other',
          'remarriageEndCauseExplanation' => 'The marriage ended due to unforeseen circumstances.',
          'claimantHasAdditionalMarriages' => false
        }
        service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
        service.merge_claimant_remarriage_fields
        expect(service.fields).to include(
          'REMARRIED_AFTER_VET_DEATH_YES' => true,
          'REMARRIED_AFTER_VET_DEATH_NO' => false,
          'ADDITIONAL_MARRIAGES_Y' => false,
          'ADDITIONAL_MARRIAGES_N' => true,
          'CLAIMANT_REMARRIAGE_1_DATE' => nil,
          'CLAIMANT_REMARRIAGE_1_DATE_ENDED' => nil,
          'REMARRIAGE_OTHER_EXPLANATION' => 'The marriage ended due to unforeseen circumstances.',
          'CB_REMARRIAGE_END_BY_DEATH' => false,
          'CB_REMARRIAGE_END_BY_DIVORCE' => false,
          'CB_MARRIAGE_DID_NOT_END' => false,
          'CB_REMARRIAGE_END_BY_OTHER' => true
        )
      end
    end
  end

  describe '#expand_and_merge_remarriage_end_cause' do
    it 'does not merge fields if has_remarried is false' do
      form = {
        'remarriedAfterVeteralDeath' => false,
        'remarriageEndCause' => 'death'
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.expand_and_merge_remarriage_end_cause(false, 'death')
      expect(service.fields).to include(
        {
          'CB_REMARRIAGE_END_BY_DEATH' => nil,
          'CB_REMARRIAGE_END_BY_DIVORCE' => nil,
          'CB_MARRIAGE_DID_NOT_END' => nil,
          'CB_REMARRIAGE_END_BY_OTHER' => nil
        }
      )
    end

    it 'merges remarriage end cause fields when has_remarried is true' do
      form = {
        'remarriedAfterVeteralDeath' => true,
        'remarriageEndCause' => 'death'
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.expand_and_merge_remarriage_end_cause(true, 'death')
      expect(service.fields).to include(
        {
          'CB_REMARRIAGE_END_BY_DEATH' => true,
          'CB_REMARRIAGE_END_BY_DIVORCE' => false,
          'CB_MARRIAGE_DID_NOT_END' => false,
          'CB_REMARRIAGE_END_BY_OTHER' => false
        }
      )
    end
  end
end
