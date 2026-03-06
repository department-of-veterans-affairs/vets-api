# frozen_string_literal: true

require 'rails_helper'
require 'survivors_benefits/structured_data/section_08'

RSpec.describe SurvivorsBenefits::StructuredData::Section08 do
  describe '#build_section8' do
    it 'merges correct fields for claimant living in a nursing home' do
      form = { 'claimantLivesInANursingHome' => true }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.build_section8
      expect(service.fields).to include(
        'CL_IN_NURSING_HOME_Y' => true,
        'CL_IN_NURSING_HOME_N' => false
      )
    end

    it 'merges correct fields for claimant not living in a nursing home' do
      form = { 'claimantLivesInANursingHome' => false }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.build_section8
      expect(service.fields).to include(
        'CL_IN_NURSING_HOME_Y' => false,
        'CL_IN_NURSING_HOME_N' => true
      )
    end

    it 'merges correct fields for claiming monthly special pension' do
      form = { 'claimingMonthlySpecialPension' => true }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.build_section8
      expect(service.fields).to include(
        'SPECIAL_ISSUE_YES' => true,
        'SPECIAL_ISSUE_NO' => false
      )
    end

    it 'merges correct fields for not claiming monthly special pension' do
      form = { 'claimingMonthlySpecialPension' => false }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.build_section8
      expect(service.fields).to include(
        'SPECIAL_ISSUE_YES' => false,
        'SPECIAL_ISSUE_NO' => true
      )
    end
  end
end
